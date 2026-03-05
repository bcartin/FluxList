import Foundation
import SwiftData

/// The local representation of a user profile, persisted with SwiftData.
///
/// A `User` can exist in two modes:
/// - **Signed out** – only the local SwiftData `id` is set; data lives on-device only.
/// - **Signed in** – `firebaseUID` is populated after Firebase Auth, enabling cloud sync.
///
/// Use ``stableID`` as the canonical identifier when referencing users across the app
/// (e.g. in ``TaskList/userIDs`` or ``ListItem/createdBy``).
@Model
final class User: Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    var email: String = ""
    /// The Firebase Authentication UID, set after sign-in. Nil for offline-only users.
    var firebaseUID: String?

    /// UUIDs (as strings) of ``TaskList`` entries the user has marked as favorites.
    /// Favorites appear in the dedicated favorites section on the home screen.
    var favoriteListIDs: [String] = []

    /// User-curated list of commonly added item names shown as quick-add suggestions
    /// when typing in the ``AddItemBar``.
    var favoriteSuggestions: [String] = []

    /// Tracks how many times each item name has been added (lowercased keys).
    /// Stored as JSON-encoded `Data` because SwiftData does not support dictionary properties.
    /// Access via ``getItemFrequencies()`` and ``setItemFrequencies(_:)``.
    var itemFrequenciesData: Data = Data()

    /// `stableID` values of other users this user has added as friends,
    /// enabling list sharing and collaboration.
    var friends: [String] = []

    /// Returns the user's Firebase UID if available, otherwise falls back to the local SwiftData UUID.
    /// Use this as the canonical identifier when storing user references (e.g. in `TaskList.userIDs`).
    var stableID: String {
        firebaseUID ?? id.uuidString
    }

    init(name: String, email: String, firebaseUID: String? = nil) {
        self.id = UUID()
        self.name = name
        self.email = email
        self.firebaseUID = firebaseUID
    }
}

extension User {
    /// Decodes the JSON-encoded ``itemFrequenciesData`` into a dictionary mapping
    /// lowercased item names to their usage counts. Returns an empty dictionary if no data is stored.
    func getItemFrequencies() -> [String: Int] {
        guard !itemFrequenciesData.isEmpty else { return [:] }
        return (try? JSONDecoder().decode([String: Int].self, from: itemFrequenciesData)) ?? [:]
    }

    /// Encodes the given frequency dictionary as JSON and writes it to ``itemFrequenciesData``.
    func setItemFrequencies(_ frequencies: [String: Int]) {
        itemFrequenciesData = (try? JSONEncoder().encode(frequencies)) ?? Data()
    }
}

