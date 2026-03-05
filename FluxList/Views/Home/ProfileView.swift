import OSLog
import SwiftUI
import SwiftData

private let logger = Logger(subsystem: "com.fluxlist", category: "ProfileView")

/// A sheet that lets the user edit their name and email.
struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UserManager.self) private var userManager
    @Environment(AuthManager.self) private var authManager
    @Environment(StoreKitManager.self) private var storeKitManager
    @Environment(FirebaseSyncManager.self) private var firebaseSyncManager
    @Environment(HomeViewModel.self) private var homeViewModel

    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var email = ""
    @State private var isShowingSignIn = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    HStack {
                        TextField("Your name", text: $name)
                            .textContentType(.name)
                            .autocorrectionDisabled()

                        if storeKitManager.isProUser {
                            Text("PRO")
                                .font(.caption)
                                .bold()
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppTheme.brandGradient, in: .capsule)
                        }
                    }
                }

                if authManager.isSignedIn {
                    Section("Email") {
                        Text(email)
                            .foregroundStyle(.secondary)
                    }
                }

                if storeKitManager.isProUser { Section("Account") {
                    if authManager.isSignedIn {
                        Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right") {
                            try? authManager.signOut()
                        }
                        .foregroundStyle(AppTheme.gradientMid)
                    } else {
                        Button("Sign In", systemImage: "person.badge.key") {
                            isShowingSignIn = true
                        }
                        .foregroundStyle(AppTheme.gradientMid)
                    }
                } }
            }
            .navigationDestination(isPresented: $isShowingSignIn) {
                SignInView(initialMode: .signIn)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .bold()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppTheme.brandGradient, in: .capsule)
                            .fixedSize()
                    }
                    .buttonStyle(.borderless)
                }
                .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        userManager.updateUser(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            email: email.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        dismiss()
                    } label: {
                        Text("Save")
                            .bold()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppTheme.brandGradient, in: .capsule)
                            .fixedSize()
                    }
                    .buttonStyle(.borderless)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .onAppear {
                name = userManager.currentUser?.name ?? ""
                email = userManager.currentUser?.email ?? ""
            }
            .onChange(of: authManager.isSignedIn) { _, isSignedIn in
                if isSignedIn {
                    Task {
                        // Pull down user profile, projects, and lists from Firestore
                        if let user = userManager.currentUser {
                            try? await firebaseSyncManager.fetchUserProfile(for: user)
                            name = user.name
                            email = user.email
                        }
                        // Fetch projects before lists so lists can be linked to projects
                        try? await firebaseSyncManager.fetchAndMergeRemoteProjects(into: modelContext)
                        try? await firebaseSyncManager.fetchAndMergeRemoteLists(into: modelContext)
                        homeViewModel.loadData()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let container = SampleData.sampleContainer
    let context = container.mainContext
    let am = AuthManager()
    let skm = StoreKitManager()
    let um: UserManager = {
        let m = UserManager(modelContext: context)
        m.fetchOrCreateCurrentUser()
        return m
    }()
    let tlm = TaskListManager(modelContext: context)
    let pm = ProjectManager(modelContext: context)
    let lim = ListItemManager(modelContext: context)

    return ProfileView()
        .modelContainer(container)
        .environment(um)
        .environment(am)
        .environment(skm)
        .environment(FirebaseSyncManager(authManager: am, storeKitManager: skm))
        .environment(HomeViewModel(taskListManager: tlm, projectManager: pm, listItemManager: lim))
}

