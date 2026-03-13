import Foundation
import OSLog
import SwiftData

private let logger = Logger(subsystem: "com.fluxlist", category: "UserManager")

/// Manages the current user's profile, favorites, suggestions, and friend list.
///
/// On first launch, ``fetchOrCreateCurrentUser()`` either loads an existing
/// ``User`` from SwiftData or creates a default one. All subsequent profile
/// mutations are saved locally and synced to Firestore when available.
///
/// Also provides ``resolveUserNames(for:)`` to look up display names for user IDs
/// encountered in shared lists — checking the local database first and falling back
/// to Firestore for unknown IDs.
@MainActor @Observable
final class UserManager {
    private let modelContext: ModelContext
    private var syncManager: FirebaseSyncManager?
    /// The pending user sync task, cancelled and replaced on each mutation
    /// so rapid changes coalesce into a single Firestore write.
    private var pendingSyncTask: Task<Void, Never>?

    /// The locally persisted user profile. Always non-nil after ``fetchOrCreateCurrentUser()`` runs.
    private(set) var currentUser: User?

    /// Cache of user ID → display name, populated from local data and Firebase lookups.
    /// Used by views that need to show who created or shares a list.
    private(set) var userNameCache: [String: String] = [:]

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Call once after FirebaseSyncManager is available to enable sync.
    func setSyncManager(_ syncManager: FirebaseSyncManager) {
        self.syncManager = syncManager
    }

    /// Persists any pending changes in the model context to disk.
    private func save() {
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save context: \(error.localizedDescription)")
        }
    }

    /// Debounces the user profile sync to Firestore.
    ///
    /// Cancels any previously pending sync and schedules a new one after a short delay,
    /// so rapid mutations (e.g. toggling multiple favorites) result in a single write.
    private func syncCurrentUser() {
        guard let user = currentUser, let syncManager else { return }
        pendingSyncTask?.cancel()
        pendingSyncTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            do {
                try await syncManager.syncUser(user)
            } catch {
                logger.error("Failed to sync user: \(error.localizedDescription)")
            }
            pendingSyncTask = nil
        }
    }

    /// Loads the existing user from SwiftData, or creates a default "Me" user on first launch.
    func fetchOrCreateCurrentUser() {
        let descriptor = FetchDescriptor<User>()
        let users: [User]
        do {
            users = try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch users: \(error.localizedDescription)")
            users = []
        }
        if let existing = users.first {
            currentUser = existing
        } else {
            let user = User(name: "Me", email: "")
            modelContext.insert(user)
            currentUser = user
        }
    }

    /// Updates the user's display name and email, then persists and syncs.
    func updateUser(name: String, email: String) {
        currentUser?.name = name
        currentUser?.email = email
        save()
        syncCurrentUser()
    }

    /// Adds or removes a list from the user's favorites.
    func toggleFavorite(list: TaskList) {
        guard let user = currentUser else { return }
        let listID = list.id.uuidString
        if let index = user.favoriteListIDs.firstIndex(of: listID) {
            user.favoriteListIDs.remove(at: index)
        } else {
            user.favoriteListIDs.append(listID)
        }
        save()
        syncCurrentUser()
    }

    /// Returns `true` if the given list is in the user's favorites.
    func isFavorite(list: TaskList) -> Bool {
        currentUser?.favoriteListIDs.contains(list.id.uuidString) ?? false
    }

    // MARK: - Push Notification Token

    /// Saves or updates the push notification device token for the current user,
    /// then persists locally and syncs to Firebase.
    func saveToken(_ token: String) {
        guard let user = currentUser else { return }
        user.token = token
        save()
        syncCurrentUser()
    }

    // MARK: - Favorite Suggestions

    /// Manually adds a suggestion to the user's quick-add list (no-op if already present).
    func addFavoriteSuggestion(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let user = currentUser else { return }
        guard !user.favoriteSuggestions.contains(trimmed) else { return }
        user.favoriteSuggestions.append(trimmed)
        save()
        syncCurrentUser()
    }

    /// Increments the frequency count for the given item name and auto-promotes
    /// it to favorite suggestions once it reaches ``ProFeatures/autoFavoriteThreshold``.
    func recordItemFrequency(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let user = currentUser else { return }

        let key = trimmed.lowercased()
        var frequencies = user.getItemFrequencies()
        let newCount = (frequencies[key] ?? 0) + 1
        frequencies[key] = newCount
        user.setItemFrequencies(frequencies)

        if newCount >= ProFeatures.autoFavoriteThreshold {
            addFavoriteSuggestion(trimmed)
        }

        save()
        syncCurrentUser()
    }

    /// Removes a favorite suggestion by its position in the array.
    func removeFavoriteSuggestion(at index: Int) {
        guard let user = currentUser,
              user.favoriteSuggestions.indices.contains(index) else { return }
        user.favoriteSuggestions.remove(at: index)
        save()
        syncCurrentUser()
    }

    // MARK: - Friends

    /// Adds another user's `stableID` to the current user's friend list.
    func addFriend(_ friendID: String) {
        guard let user = currentUser,
              !user.friends.contains(friendID) else { return }
        user.friends.append(friendID)
        save()
        syncCurrentUser()
    }

    /// Removes a friend by their `stableID`.
    func removeFriend(_ friendID: String) {
        guard let user = currentUser,
              let index = user.friends.firstIndex(of: friendID) else { return }
        user.friends.remove(at: index)
        save()
        syncCurrentUser()
    }

    // MARK: - User Name Resolution

    /// Returns the cached display name for a user ID, or `nil` if not yet resolved.
    func displayName(for userID: String) -> String? {
        userNameCache[userID]
    }

    /// Resolves display names for a set of user IDs.
    ///
    /// Resolution order:
    /// 1. In-memory cache (``userNameCache``).
    /// 2. Current user match (by `stableID` or local UUID).
    /// 3. Local SwiftData lookup (by `firebaseUID`, then by UUID).
    /// 4. Remote Firestore lookup (in a background task) for any remaining unknowns.
    func resolveUserNames(for userIDs: [String]) {
        var unknownIDs: [String] = []

        for userID in userIDs {
            guard userNameCache[userID] == nil else { continue }

            // Check if it matches the current user (by stableID or local UUID)
            if let currentUser,
               userID == currentUser.stableID || userID == currentUser.id.uuidString {
                userNameCache[userID] = currentUser.name
                continue
            }

            // Try local SwiftData lookup by firebaseUID
            let searchID = userID
            let firebaseDescriptor = FetchDescriptor<User>(
                predicate: #Predicate { $0.firebaseUID == searchID }
            )
            if let localUser = (try? modelContext.fetch(firebaseDescriptor))?.first {
                userNameCache[userID] = localUser.name
                continue
            }

            // Try local SwiftData lookup by UUID
            if let uuid = UUID(uuidString: userID) {
                let descriptor = FetchDescriptor<User>(
                    predicate: #Predicate { $0.id == uuid }
                )
                if let localUser = (try? modelContext.fetch(descriptor))?.first {
                    userNameCache[userID] = localUser.name
                    continue
                }
            }

            unknownIDs.append(userID)
        }

        // Fetch remaining unknown IDs from Firebase in the background
        guard !unknownIDs.isEmpty, let syncManager else { return }
        Task {
            for userID in unknownIDs {
                do {
                    if let remoteUser = try await syncManager.fetchUser(byID: userID) {
                        userNameCache[userID] = remoteUser.name
                    }
                } catch {
                    logger.error("Failed to fetch user name for '\(userID)': \(error.localizedDescription)")
                }
            }
        }
    }
}
