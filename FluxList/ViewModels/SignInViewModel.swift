import Foundation
import OSLog

private let logger = Logger(subsystem: "com.fluxlist", category: "SignInViewModel")

/// Backs the sign-in / create-account sheet, handling form validation,
/// Firebase authentication calls, and password-reset flow.
///
/// The view model supports two ``Mode``s that the user can toggle between:
/// - **createAccount** – registers a new Firebase user.
/// - **signIn** – authenticates an existing Firebase user.
///
/// After successful authentication, `didAuthenticate` is set to `true`
/// so the presenting view can dismiss the sheet.
@MainActor @Observable
final class SignInViewModel {
    /// Whether the sheet is in "Create Account" or "Sign In" mode.
    enum Mode {
        case createAccount
        case signIn
    }

    private let authManager: AuthManager
    private let userManager: UserManager

    /// The current authentication mode (create vs. sign in).
    var mode: Mode = .createAccount
    /// Email text field value, optionally pre-populated from the user's profile.
    var email: String
    /// Password text field value.
    var password: String = ""
    /// `true` while an auth request is in flight.
    private(set) var isLoading = false
    /// User-facing error message from a failed auth attempt.
    var errorMessage: String?
    /// Controls the "reset email sent" confirmation alert.
    var isShowingResetConfirmation = false
    /// Set to `true` after a successful sign-in or account creation.
    private(set) var didAuthenticate = false

    /// Whether the form has enough data to submit (non-blank email + non-empty password).
    var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !password.isEmpty
    }

    /// The label for the primary action button, based on the current mode.
    var submitButtonTitle: String {
        switch mode {
        case .createAccount: "Create Account"
        case .signIn: "Sign In"
        }
    }

    /// The text shown on the mode-toggle button (e.g. "Already have an account?").
    var togglePrompt: String {
        switch mode {
        case .createAccount: "Already have an account? Sign in"
        case .signIn: "Don't have an account? Create one"
        }
    }

    /// The navigation bar title for the sheet.
    var navigationTitle: String {
        switch mode {
        case .createAccount: "Create Account"
        case .signIn: "Sign In"
        }
    }

    init(initialEmail: String, authManager: AuthManager, userManager: UserManager) {
        self.email = initialEmail
        self.authManager = authManager
        self.userManager = userManager
    }

    /// Switches between create-account and sign-in mode, clearing transient state.
    func toggleMode() {
        switch mode {
        case .createAccount: mode = .signIn
        case .signIn: mode = .createAccount
        }
        password = ""
        errorMessage = nil
    }

    /// Dispatches to the appropriate auth method based on the current mode.
    func submit() async {
        switch mode {
        case .signIn: await signIn()
        case .createAccount: await createAccount()
        }
    }

    /// Authenticates an existing user with Firebase and links the local User model.
    private func signIn() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            try await authManager.signIn(email: trimmedEmail, password: password)

            // Link the Firebase UID to the local SwiftData user so sync can work.
            if let uid = authManager.currentUserID {
                userManager.currentUser?.firebaseUID = uid
            }

            didAuthenticate = true
        } catch {
            logger.error("Sign in failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Creates a new Firebase account and links it to the local User model.
    private func createAccount() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            try await authManager.signUp(email: trimmedEmail, password: password)

            if let uid = authManager.currentUserID {
                userManager.currentUser?.firebaseUID = uid
                userManager.currentUser?.email = trimmedEmail
            }

            didAuthenticate = true
        } catch {
            logger.error("Account creation failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Sends a password-reset email via Firebase. Shows a confirmation alert on success.
    func sendPasswordReset() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            errorMessage = "Enter your email address first."
            return
        }

        errorMessage = nil

        do {
            try await authManager.sendPasswordReset(email: trimmedEmail)
            isShowingResetConfirmation = true
        } catch {
            logger.error("Password reset failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
}
