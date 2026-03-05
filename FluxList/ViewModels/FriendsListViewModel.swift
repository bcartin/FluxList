import Foundation
import OSLog

private let logger = Logger(subsystem: "com.fluxlist", category: "FriendsListViewModel")

/// Backs the "Friends" management screen where the user can view and remove
/// people they've previously shared lists with.
///
/// Friend IDs are stored locally on the ``User`` model. On load, each ID is
/// resolved to a display name and email by fetching from Firestore.
@MainActor @Observable
final class FriendsListViewModel {
    // MARK: - Dependencies

    private let userManager: UserManager
    private let firebaseSyncManager: FirebaseSyncManager

    // MARK: - State

    /// Search bar text used to filter the friends list.
    var searchText: String = ""
    /// Fully resolved friend information loaded from Firestore.
    private(set) var friends: [FriendInfo] = []
    /// `true` while friends are being fetched from Firestore.
    private(set) var isLoading: Bool = false

    // MARK: - Display Model

    /// A resolved friend entry with display-ready name and email.
    struct FriendInfo: Identifiable {
        let id: String
        let name: String
        let email: String
    }

    /// Friends filtered by the current search text.
    var filteredFriends: [FriendInfo] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return friends }
        return friends.filter {
            $0.name.localizedStandardContains(query) ||
            $0.email.localizedStandardContains(query)
        }
    }

    // MARK: - Init

    init(userManager: UserManager, firebaseSyncManager: FirebaseSyncManager) {
        self.userManager = userManager
        self.firebaseSyncManager = firebaseSyncManager
    }

    // MARK: - Load

    /// Resolves the current user's friend IDs into display-ready FriendInfo values.
    func loadFriends() async {
        guard let friendIDs = userManager.currentUser?.friends else { return }
        isLoading = true
        defer { isLoading = false }

        var resolved: [FriendInfo] = []
        for friendID in friendIDs {
            do {
                if let remote = try await firebaseSyncManager.fetchUser(byID: friendID) {
                    resolved.append(FriendInfo(
                        id: remote.uid,
                        name: remote.name,
                        email: remote.email
                    ))
                } else {
                    let cachedName = userManager.userNameCache[friendID] ?? friendID
                    resolved.append(FriendInfo(id: friendID, name: cachedName, email: ""))
                }
            } catch {
                logger.error("Failed to fetch friend '\(friendID)': \(error.localizedDescription)")
                let cachedName = userManager.userNameCache[friendID] ?? friendID
                resolved.append(FriendInfo(id: friendID, name: cachedName, email: ""))
            }
        }
        friends = resolved
    }

    // MARK: - Delete

    /// Removes a friend at the given offset from the filtered list,
    /// then persists the change through UserManager.
    func deleteFriends(at offsets: IndexSet) {
        let currentFiltered = filteredFriends
        for index in offsets {
            let friend = currentFiltered[index]
            userManager.removeFriend(friend.id)
            friends.removeAll { $0.id == friend.id }
        }
    }
}
