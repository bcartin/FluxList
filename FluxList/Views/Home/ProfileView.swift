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
                SignInView()
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
        }
    }
}

// MARK: - Preview

#Preview {
    ProfileView()
        .modelContainer(SampleData.sampleContainer)
        .environment({
            let um = UserManager(modelContext: SampleData.sampleContainer.mainContext)
            um.fetchOrCreateCurrentUser()
            return um
        }())
        .environment(AuthManager())
        .environment(StoreKitManager())
}

