import Foundation
import FirebaseAuth

/// Wraps Firebase Authentication, providing sign-in / sign-up / sign-out and
/// a reactive ``isSignedIn`` flag that the rest of the app can observe.
///
/// The manager also exposes the raw ``firebaseUser`` so other components
/// (e.g. ``FirebaseSyncManager``) can read the current UID.
@MainActor @Observable
final class AuthManager {
    /// The currently authenticated Firebase user, or `nil` if signed out.
    private(set) var firebaseUser: FirebaseAuth.User?
    /// Handle to the Firebase auth-state listener so it can be removed in `deinit`.
    private nonisolated(unsafe) var authStateHandle: AuthStateDidChangeListenerHandle?

    /// Convenience check — `true` when a Firebase user session is active.
    var isSignedIn: Bool { firebaseUser != nil }

    /// The Firebase UID of the currently signed-in user, if any.
    var currentUserID: String? { firebaseUser?.uid }

    /// Starts listening for auth state changes from Firebase.
    /// Uses `withCheckedContinuation` to **wait** for the initial auth state
    /// before returning, so callers know auth is resolved on first launch.
    func listenForAuthChanges() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var didResume = false
            authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
                Task { @MainActor [weak self] in
                    self?.firebaseUser = user
                    // Resume the continuation only once — for the initial state.
                    if !didResume {
                        didResume = true
                        continuation.resume()
                    }
                }
            }
        }
    }

    /// Signs in an existing user with email and password.
    func signIn(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        firebaseUser = result.user
    }

    /// Creates a new Firebase account and signs the user in immediately.
    func signUp(email: String, password: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        firebaseUser = result.user
    }

    /// Sends a password-reset email via Firebase.
    func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    /// Signs out the current user locally and from Firebase.
    func signOut() throws {
        try Auth.auth().signOut()
        firebaseUser = nil
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
