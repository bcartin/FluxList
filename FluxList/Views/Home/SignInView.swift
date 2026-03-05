import SwiftUI
import SwiftData

/// The entry point for the sign-in / create-account flow, presented as a sheet.
///
/// Creates a ``SignInViewModel`` lazily once environment objects are available,
/// pre-populating the email from the current user's profile if one exists.
struct SignInView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(UserManager.self) private var userManager
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: SignInViewModel?

    var body: some View {
        Group {
            if let viewModel {
                SignInContentView(viewModel: viewModel, onComplete: { dismiss() })
            } else {
                ProgressView()
            }
        }
        .navigationTitle(viewModel?.navigationTitle ?? "Create Account")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                viewModel = SignInViewModel(
                    initialEmail: userManager.currentUser?.email ?? "",
                    authManager: authManager,
                    userManager: userManager
                )
            }
        }
    }
}

// MARK: - Content

/// The form UI for sign-in / create-account, extracted so the outer view
/// can manage loading state and the view model lifecycle.
struct SignInContentView: View {
    @Bindable var viewModel: SignInViewModel
    /// Called after successful authentication so the presenting view can dismiss.
    let onComplete: () -> Void

    var body: some View {
        Form {
            Section("Email") {
                TextField("you@example.com", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("Password") {
                SecureField("Password", text: $viewModel.password)
                    .textContentType(viewModel.mode == .createAccount ? .newPassword : .password)
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }
            }

            Section {
                Button {
                    Task {
                        await viewModel.submit()
                        if viewModel.didAuthenticate {
                            onComplete()
                        }
                    }
                } label: {
                    Group {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text(viewModel.submitButtonTitle)
                                .bold()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.white)
                    .padding(.vertical, 8)
                    .background(AppTheme.brandGradient, in: .capsule)
                }
                .buttonStyle(.borderless)
                .disabled(!viewModel.canSubmit || viewModel.isLoading)

                if viewModel.mode == .createAccount {
                    Text("By creating an account you agree to our [\("Privacy Policy")](https://example.com/privacy).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }
            .listRowBackground(Color.clear)

            Section {
                Button(viewModel.togglePrompt) {
                    withAnimation {
                        viewModel.toggleMode()
                    }
                }
                .font(.subheadline)
                .foregroundStyle(AppTheme.gradientMid)
                .frame(maxWidth: .infinity)

                if viewModel.mode == .signIn {
                    Button("Forgot password?") {
                        Task {
                            await viewModel.sendPasswordReset()
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                }
            }
            .listRowBackground(Color.clear)
        }
        .alert("Password Reset Sent", isPresented: $viewModel.isShowingResetConfirmation) {
            Button("OK") {}
        } message: {
            Text("Check your email for a link to reset your password.")
        }
    }
}

// MARK: - Preview

#Preview("Create Account") {
    @Previewable @State var viewModel = {
        let schema = Schema([User.self, Project.self, TaskList.self, ListItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let userManager = UserManager(modelContext: container.mainContext)
        return SignInViewModel(
            initialEmail: "robert.cartin@gmail.com",
            authManager: AuthManager(),
            userManager: userManager
        )
    }()

    NavigationStack {
        SignInContentView(viewModel: viewModel, onComplete: {})
            .navigationTitle(viewModel.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Sign In") {
    @Previewable @State var viewModel = {
        let schema = Schema([User.self, Project.self, TaskList.self, ListItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let userManager = UserManager(modelContext: container.mainContext)
        let vm = SignInViewModel(
            initialEmail: "robert.cartin@gmail.com",
            authManager: AuthManager(),
            userManager: userManager
        )
        vm.toggleMode()
        return vm
    }()

    NavigationStack {
        SignInContentView(viewModel: viewModel, onComplete: {})
            .navigationTitle(viewModel.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
    }
}

