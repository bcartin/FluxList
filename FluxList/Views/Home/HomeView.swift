import SwiftUI
import SwiftData

/// The root view of the app, displaying the user's task lists as expandable cards.
///
/// Supports three layout modes based on the current filter:
/// - **All / Project filter** — a scrollable stack of ``ListCardView`` cards with a FAB.
/// - **Single list filter** — an inline ``SingleListContentView`` for focused item management.
/// - **Empty state** — a call-to-action when no lists exist yet.
///
/// The toolbar contains the ``UserMenu`` (leading), ``ViewFilterMenu`` (center),
/// and an overflow menu (trailing) for actions like clearing completed items.
/// Sheets for creating lists, editing, paywall, projects, etc. are all presented from here.
struct HomeView: View {
    @Environment(Router.self) private var router
    @Environment(HomeViewModel.self) private var viewModel
    @Environment(ListItemManager.self) private var listItemManager
    @Environment(UserManager.self) private var userManager
    @Environment(StoreKitManager.self) private var storeKitManager

    @State private var isShowingListLimitAlert = false
    @State private var isShowingEditList = false

    /// Opens the create-list sheet, or shows a paywall alert if the free-tier limit is reached.
    private func createListOrShowLimit() {
        if !storeKitManager.isProUser && viewModel.allLists.count >= FreeTierLimits.maxLists {
            isShowingListLimitAlert = true
        } else {
            router.isShowingCreateList = true
        }
    }

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            Group {
                if viewModel.isFilteringToSingleList, let list = viewModel.selectedList {
                    SingleListContentView(
                        list: list,
                        listItemManager: listItemManager,
                        userID: userManager.currentUser?.stableID ?? "",
                        favoriteSuggestions: userManager.currentUser?.favoriteSuggestions ?? []
                    )
                } else if viewModel.filteredLists.isEmpty {
                    EmptyListsView {
                        createListOrShowLimit()
                    }
                } else {
                    ZStack(alignment: .bottomTrailing) {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.filteredLists) { list in
                                    ListCardView(
                                        list: list,
                                        isExpanded: viewModel.isExpanded(list),
                                        onToggleExpansion: {
                                            withAnimation(.snappy) {
                                                viewModel.toggleExpansion(for: list)
                                            }
                                        },
                                        onToggleItem: { item in
                                            withAnimation {
                                                listItemManager.toggleCompletion(item)
                                            }
                                        },
                                        onAddItem: {
                                            router.navigate(to: .listDetail(list))
                                        }
                                    )
                                }
                            }
                            .padding()
                        }
                        .scrollIndicators(.hidden)

                        FloatingActionButton {
                            createListOrShowLimit()
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    UserMenu()
                }
                .sharedBackgroundVisibility(.hidden)

                ToolbarItem(placement: .principal) {
                    ViewFilterMenu()
                }
                .sharedBackgroundVisibility(.hidden)

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if viewModel.isFilteringToSingleList {
                            Button("Edit List", systemImage: "pencil") {
                                isShowingEditList = true
                            }
                        }
                        Button("Clear completed", systemImage: "trash", role: .destructive) {
                            withAnimation {
                                viewModel.clearCompleted()
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .bold()
                            .foregroundStyle(.white)
                            .padding(16)
                            .background(AppTheme.brandGradient, in: .circle)
                    }
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .listDetail(let listID):
                    ListDetailView(listID: listID)
                case .paywall:
                    PaywallView()
                }
            }
            .sheet(isPresented: $router.isShowingCreateList) {
                CreateListSheet()
            }
            .sheet(isPresented: $isShowingEditList) {
                if let list = viewModel.selectedList {
                    CreateListSheet(editing: list)
                }
            }
            .sheet(isPresented: $router.isShowingPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $router.isShowingProjects) {
                ProjectsListView()
            }
            .sheet(isPresented: $router.isShowingListsOverview) {
                ListsOverviewView()
            }
            .sheet(isPresented: $router.isShowingFavorites) {
                FavoritesListView()
            }
            .sheet(isPresented: $router.isShowingFriends) {
                FriendsListView()
            }
            .sheet(isPresented: $router.isShowingProfile) {
                ProfileView()
            }
            .alert("List Limit Reached", isPresented: $isShowingListLimitAlert) {
                Button("Upgrade to Pro", role: .confirm) {
                    router.isShowingPaywall = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Free users can create up to \(FreeTierLimits.maxLists) lists. Upgrade to Pro for unlimited lists.")
            }
            .onAppear {
                viewModel.loadData()
            }
        }
    }
}

// MARK: - Empty State

/// Placeholder shown when the user has no lists, with a button to create one.
private struct EmptyListsView: View {
    let onCreate: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No Lists Yet", systemImage: "list.bullet.rectangle")
                .foregroundStyle(AppTheme.brandGradient)
        } description: {
            Text("Create your first list to start organizing your tasks.")
        } actions: {
            Button("Create a List", systemImage: "plus", action: onCreate)
                .buttonStyle(.borderedProminent)
                .padding(.top)
        }
    }
}

// MARK: - Previews

#Preview("All Lists") {
    HomeView()
        .modelContainer(SampleData.sampleContainer)
        .environment(Router())
        .environment({
            let container = SampleData.sampleContainer
            let context = container.mainContext
            let lim = ListItemManager(modelContext: context)
            let vm = HomeViewModel(
                taskListManager: TaskListManager(modelContext: context),
                projectManager: ProjectManager(modelContext: context),
                listItemManager: lim
            )
            return vm
        }())
        .environment(ListItemManager(modelContext: SampleData.sampleContainer.mainContext))
        .environment({
            let um = UserManager(modelContext: SampleData.sampleContainer.mainContext)
            um.fetchOrCreateCurrentUser()
            return um
        }())
        .environment(StoreKitManager())
        .environment(AuthManager())
}
#Preview("Empty") {
    let schema = Schema([User.self, Project.self, TaskList.self, ListItem.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    let context = container.mainContext

    HomeView()
        .modelContainer(container)
        .environment(Router())
        .environment(HomeViewModel(
            taskListManager: TaskListManager(modelContext: context),
            projectManager: ProjectManager(modelContext: context),
            listItemManager: ListItemManager(modelContext: context)
        ))
        .environment(ListItemManager(modelContext: context))
        .environment({
            let um = UserManager(modelContext: context)
            um.fetchOrCreateCurrentUser()
            return um
        }())
        .environment(StoreKitManager())
        .environment(AuthManager())
}
#Preview("Single List") {
    HomeView()
        .modelContainer(SampleData.sampleContainer)
        .environment(Router())
        .environment({
            let container = SampleData.sampleContainer
            let context = container.mainContext
            let lim = ListItemManager(modelContext: context)
            let vm = HomeViewModel(
                taskListManager: TaskListManager(modelContext: context),
                projectManager: ProjectManager(modelContext: context),
                listItemManager: lim
            )
            vm.loadData()
            if let first = vm.allLists.first {
                vm.selectList(first)
            }
            return vm
        }())
        .environment(ListItemManager(modelContext: SampleData.sampleContainer.mainContext))
        .environment({
            let um = UserManager(modelContext: SampleData.sampleContainer.mainContext)
            um.fetchOrCreateCurrentUser()
            return um
        }())
        .environment(StoreKitManager())
        .environment(AuthManager())
}

