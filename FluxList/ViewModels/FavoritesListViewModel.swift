import Foundation

/// Drives the "Favorite Suggestions" management screen where users can view,
/// search, add, and remove their quick-add item suggestions.
///
/// Suggestions are stored on the ``User`` model and surfaced in the add-item bar
/// for one-tap creation of frequently used items.
@MainActor @Observable
final class FavoritesListViewModel {
    private let userManager: UserManager

    /// The full list of the user's favorite suggestion strings.
    var favorites: [String] = []
    /// Text from the search bar, used to filter the displayed list.
    var searchText: String = ""

    /// Favorites filtered by the current search query (case-insensitive, locale-aware).
    var filteredFavorites: [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return favorites }
        return favorites.filter { $0.localizedStandardContains(query) }
    }

    // MARK: - Create alert state

    /// Controls whether the "Add new suggestion" alert is presented.
    var isShowingCreateAlert = false
    /// The text field value inside the create alert.
    var newFavoriteName = ""

    init(userManager: UserManager) {
        self.userManager = userManager
    }

    /// Reloads the favorites array from the current user's profile.
    func loadFavorites() {
        favorites = userManager.currentUser?.favoriteSuggestions ?? []
    }

    /// Removes a suggestion at the given index and refreshes the list.
    func deleteFavorite(at index: Int) {
        userManager.removeFavoriteSuggestion(at: index)
        loadFavorites()
    }

    /// Prepares the create alert for presentation.
    func beginCreating() {
        newFavoriteName = ""
        isShowingCreateAlert = true
    }

    /// Commits the new suggestion, persists it, and refreshes the list.
    func confirmCreate() {
        let trimmed = newFavoriteName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        userManager.addFavoriteSuggestion(trimmed)
        newFavoriteName = ""
        loadFavorites()
    }
}
