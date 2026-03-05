import Foundation
import OSLog

private let logger = Logger(subsystem: "com.fluxlist", category: "AddPersonViewModel")

/// Drives the "Add Person" sheet, allowing the user to share a list with friends
/// or search for other users by email.
///
/// The view model merges two data sources into ``displayedPeople``:
/// 1. The current user's existing friends (fetched from Firestore on load).
/// 2. Results from an email search against all Firestore users.
///
/// Once a person is selected, their `stableID` is added to the list's shared user IDs
/// and they are also added to the current user's friend list for future convenience.
@MainActor @Observable
final class AddPersonViewModel {
    // MARK: - Dependencies

    private let userManager: UserManager
    private let firebaseSyncManager: FirebaseSyncManager

    // MARK: - State

    /// Text entered in the search bar, used to filter friends and trigger email searches.
    var searchText: String = ""
    /// `true` while a Firebase email search is in progress.
    var isSearching: Bool = false
    /// User-facing error message shown when a search fails or returns no results.
    var errorMessage: String?

    /// Resolved friend data (name + email + uid).
    private(set) var friends: [PersonResult] = []

    /// Results returned from Firebase email search.
    private(set) var searchResults: [PersonResult] = []

    /// The `stableID`s already added to the list being edited, so the UI can
    /// show them as "already added" and prevent duplicates.
    private(set) var alreadyAddedIDs: Set<String>

    // MARK: - Display Model

    /// Lightweight value type representing a user that can be added to a shared list.
    struct PersonResult: Identifiable {
        let id: String
        let name: String
        let email: String
    }

    /// The unified, filtered list shown in the UI.
    /// When searchText is empty, shows all friends.
    /// When searchText is non-empty, filters friends by name/email,
    /// then appends any search results not already in the friends list.
    var displayedPeople: [PersonResult] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        var results: [PersonResult]
        if query.isEmpty {
            results = friends
        } else {
            results = friends.filter {
                $0.name.localizedStandardContains(query) ||
                $0.email.localizedStandardContains(query)
            }
        }

        // Append search results that aren't already in the list
        let existingIDs = Set(results.map(\.id))
        for result in searchResults where !existingIDs.contains(result.id) {
            results.append(result)
        }

        return results
    }

    // MARK: - Init

    init(
        userManager: UserManager,
        firebaseSyncManager: FirebaseSyncManager,
        alreadyAddedIDs: [String]
    ) {
        self.userManager = userManager
        self.firebaseSyncManager = firebaseSyncManager
        self.alreadyAddedIDs = Set(alreadyAddedIDs)
    }

    // MARK: - Load Friends

    /// Resolves the current user's friend IDs into PersonResult values
    /// by fetching each friend from Firebase.
    func loadFriends() async {
        guard let friendIDs = userManager.currentUser?.friends else { return }

        // Resolve names in the cache for immediate use
        userManager.resolveUserNames(for: friendIDs)

        var resolved: [PersonResult] = []
        for friendID in friendIDs {
            do {
                if let remote = try await firebaseSyncManager.fetchUser(byID: friendID) {
                    resolved.append(PersonResult(
                        id: remote.uid,
                        name: remote.name,
                        email: remote.email
                    ))
                } else {
                    // User not found in Firebase — use cached name
                    let cachedName = userManager.userNameCache[friendID] ?? friendID
                    resolved.append(PersonResult(id: friendID, name: cachedName, email: ""))
                }
            } catch {
                logger.error("Failed to fetch friend '\(friendID)': \(error.localizedDescription)")
                let cachedName = userManager.userNameCache[friendID] ?? friendID
                resolved.append(PersonResult(id: friendID, name: cachedName, email: ""))
            }
        }
        friends = resolved
    }

    // MARK: - Search by Email

    /// Searches Firebase for a user with the exact email in searchText.
    func searchByEmail() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        isSearching = true
        errorMessage = nil
        searchResults = []
        defer { isSearching = false }

        do {
            if let remote = try await firebaseSyncManager.fetchUser(byEmail: query) {
                let currentID = userManager.currentUser?.stableID
                if remote.uid != currentID {
                    searchResults = [PersonResult(
                        id: remote.uid,
                        name: remote.name,
                        email: remote.email
                    )]
                } else {
                    errorMessage = "That's your own account."
                }
            } else {
                errorMessage = "No user found with that email."
            }
        } catch {
            logger.error("Email search failed: \(error.localizedDescription)")
            errorMessage = "Search failed. Please try again."
        }
    }

    // MARK: - Selection

    /// Records a user as added to the list and also saves them as a friend
    /// so they appear in the friends list for future sharing.
    func markAsAdded(_ uid: String) {
        alreadyAddedIDs.insert(uid)
        userManager.addFriend(uid)
    }

    /// Returns `true` if the given user has already been added to the current list.
    func isAlreadyAdded(_ uid: String) -> Bool {
        alreadyAddedIDs.contains(uid)
    }
}
