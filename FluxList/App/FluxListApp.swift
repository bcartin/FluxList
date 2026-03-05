import OSLog
import SwiftUI
import SwiftData

private let logger = Logger(subsystem: "com.fluxlist", category: "App")

/// The entry point of the FluxList application.
///
/// Sets up the SwiftData model container, creates all shared managers and view models,
/// and injects them into the SwiftUI environment so every view has access.
///
/// ## Initialization flow
/// 1. SwiftData `ModelContainer` is created with the full schema.
/// 2. All managers (User, Project, TaskList, ListItem, Auth, StoreKit, Sync) are instantiated.
/// 3. On first `.task`, the current user is loaded/created, products are fetched,
///    Firebase auth is resolved, sync managers are wired in, and a Firestore sync runs.
/// 4. A second `.task` listens for StoreKit transaction updates for the app's lifetime.
@main
struct FluxListApp: App {
    /// Bridges UIKit's `didFinishLaunchingWithOptions` to configure Firebase.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    /// The shared SwiftData container holding User, Project, TaskList, and ListItem models.
    let modelContainer: ModelContainer

    // MARK: - Shared state injected into the environment

    @State private var router = Router()
    @State private var storeKitManager = StoreKitManager()
    @State private var authManager = AuthManager()

    @State private var userManager: UserManager
    @State private var projectManager: ProjectManager
    @State private var taskListManager: TaskListManager
    @State private var listItemManager: ListItemManager
    @State private var firebaseSyncManager: FirebaseSyncManager
    @State private var homeViewModel: HomeViewModel

    init() {
        // Build the SwiftData container with all four model types.
        let schema = Schema([User.self, Project.self, TaskList.self, ListItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        self.modelContainer = container

        // Create managers that depend on the SwiftData context.
        let context = container.mainContext
        let um = UserManager(modelContext: context)
        let pm = ProjectManager(modelContext: context)
        let tlm = TaskListManager(modelContext: context)
        let lim = ListItemManager(modelContext: context)

        // Create managers that are independent of SwiftData.
        let skm = StoreKitManager()
        let am = AuthManager()
        let fsm = FirebaseSyncManager(authManager: am, storeKitManager: skm)

        let hvm = HomeViewModel(taskListManager: tlm, projectManager: pm, listItemManager: lim)

        // Wrap each manager in @State so SwiftUI owns their lifecycle.
        _userManager = State(initialValue: um)
        _projectManager = State(initialValue: pm)
        _taskListManager = State(initialValue: tlm)
        _listItemManager = State(initialValue: lim)
        _storeKitManager = State(initialValue: skm)
        _authManager = State(initialValue: am)
        _firebaseSyncManager = State(initialValue: fsm)
        _homeViewModel = State(initialValue: hvm)
    }

    @Environment(\.scenePhase) private var scenePhase
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                HomeView()
                .environment(router)
                .environment(storeKitManager)
                .environment(authManager)
                .environment(userManager)
                .environment(projectManager)
                .environment(taskListManager)
                .environment(listItemManager)
                .environment(firebaseSyncManager)
                .environment(homeViewModel)
                .task {
                    userManager.fetchOrCreateCurrentUser()
                    await storeKitManager.loadProducts()
                    await authManager.listenForAuthChanges()

                    // Wire sync manager into managers once ready
                    userManager.setSyncManager(firebaseSyncManager)
                    taskListManager.setSyncManager(firebaseSyncManager)
                    listItemManager.setSyncManager(firebaseSyncManager)
                    projectManager.setSyncManager(firebaseSyncManager)

                    // Wire frequency tracking for auto-favorites
                    listItemManager.setFrequencyTracking(
                        userManager: userManager,
                        storeKitManager: storeKitManager
                    )

                    await syncWithFirestore()

                    withAnimation(.easeOut(duration: 0.4)) {
                        showSplash = false
                    }
                }
                .task {
                    await storeKitManager.listenForTransactions()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task {
                            await syncWithFirestore()
                        }
                    }
                }
                .onChange(of: storeKitManager.isProUser) { _, isPro in
                    if isPro && !authManager.isSignedIn {
                        router.isShowingCreateAccount = true
                    }
                }
                .sheet(isPresented: $router.isShowingCreateAccount) {
                    // After the sign-in sheet is dismissed, sync with Firestore
                    // so the user's profile and shared lists are pulled down.
                    if authManager.isSignedIn {
                        Task {
                            await syncWithFirestore()
                        }
                    }
                } content: {
                    NavigationStack {
                        SignInView()
                    }
                }

                if showSplash {
                    SplashScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
        }
        .modelContainer(modelContainer)
    }

    /// Performs a full two-way Firestore sync:
    /// 1. Pulls the latest user profile from Firestore and applies it locally.
    /// 2. Pushes the local user profile back to Firestore.
    /// 3. Fetches and merges remote projects into SwiftData.
    /// 4. Pushes all local projects to Firestore.
    /// 5. Fetches and merges remote shared lists into SwiftData (linked to projects).
    /// 6. Pushes all local lists to Firestore.
    /// 7. Reloads the home screen data so the UI reflects the merged state.
    ///
    /// Called on launch and each time the app returns to the foreground.
    private func syncWithFirestore() async {
        if let user = userManager.currentUser {
            do {
                try await firebaseSyncManager.fetchUserProfile(for: user)
            } catch {
                logger.error("Failed to fetch user profile from Firestore: \(error.localizedDescription)")
            }
            do {
                try await firebaseSyncManager.syncUser(user)
            } catch {
                logger.error("Failed to sync user profile to Firestore: \(error.localizedDescription)")
            }
        }

        // Sync projects before lists so that fetched lists can be linked to projects
        do {
            try await firebaseSyncManager.fetchAndMergeRemoteProjects(into: modelContainer.mainContext)
        } catch {
            logger.error("Failed to fetch remote projects from Firestore: \(error.localizedDescription)")
        }
        do {
            let localProjects = projectManager.fetchProjects()
            try await firebaseSyncManager.syncAllProjects(localProjects)
        } catch {
            logger.error("Failed to push local projects to Firestore: \(error.localizedDescription)")
        }

        do {
            try await firebaseSyncManager.fetchAndMergeRemoteLists(into: modelContainer.mainContext)
        } catch {
            logger.error("Failed to fetch remote lists from Firestore: \(error.localizedDescription)")
        }
        do {
            let localLists = taskListManager.fetchAllLists()
            try await firebaseSyncManager.syncAllLists(localLists)
        } catch {
            logger.error("Failed to push local lists to Firestore: \(error.localizedDescription)")
        }

        // Reload home data after sync completes
        homeViewModel.loadData()
    }
}
