import Testing
import Foundation
import SwiftData
@testable import FluxList

@Suite(.serialized)
@MainActor
struct FavoritesListViewModelTests {
    private func makeSetup() -> (ModelContext, UserManager, FavoritesListViewModel) {
        let context = TestModelContainer.newContext()
        let um = UserManager(modelContext: context)
        um.fetchOrCreateCurrentUser()
        let vm = FavoritesListViewModel(userManager: um)
        return (context, um, vm)
    }

    @Test func loadFavoritesReturnsUserSuggestions() throws {
        let (_, um, vm) = makeSetup()

        um.currentUser?.favoriteSuggestions = ["Buy groceries", "Call mom"]
        vm.loadFavorites()

        #expect(vm.favorites.count == 2)
        #expect(vm.favorites == ["Buy groceries", "Call mom"])
    }

    @Test func loadFavoritesReturnsEmptyWhenNoSuggestions() throws {
        let (_, _, vm) = makeSetup()

        vm.loadFavorites()

        #expect(vm.favorites.isEmpty)
    }

    @Test func deleteFavoriteRemovesAtIndex() throws {
        let (_, um, vm) = makeSetup()

        um.currentUser?.favoriteSuggestions = ["A", "B", "C"]
        vm.loadFavorites()

        vm.deleteFavorite(at: 1)

        #expect(vm.favorites == ["A", "C"])
    }

    @Test func beginCreatingResetsNameAndShowsAlert() throws {
        let (_, _, vm) = makeSetup()

        vm.newFavoriteName = "leftover"
        vm.beginCreating()

        #expect(vm.newFavoriteName.isEmpty)
        #expect(vm.isShowingCreateAlert)
    }

    @Test func confirmCreateAddsFavoriteAndClears() throws {
        let (_, um, vm) = makeSetup()

        vm.loadFavorites()
        vm.newFavoriteName = "New task"
        vm.confirmCreate()

        #expect(vm.favorites == ["New task"])
        #expect(vm.newFavoriteName.isEmpty)
        #expect(um.currentUser?.favoriteSuggestions == ["New task"])
    }

    @Test func confirmCreateIgnoresEmptyName() throws {
        let (_, _, vm) = makeSetup()

        vm.loadFavorites()
        vm.newFavoriteName = "   "
        vm.confirmCreate()

        #expect(vm.favorites.isEmpty)
    }

    @Test func confirmCreateIgnoresDuplicates() throws {
        let (_, um, vm) = makeSetup()

        um.currentUser?.favoriteSuggestions = ["Existing"]
        vm.loadFavorites()
        vm.newFavoriteName = "Existing"
        vm.confirmCreate()

        #expect(vm.favorites.count == 1)
    }

    // MARK: - Search / Filtering

    @Test func filteredFavoritesReturnsAllWhenSearchEmpty() {
        let (_, um, vm) = makeSetup()

        um.currentUser?.favoriteSuggestions = ["Buy groceries", "Call mom"]
        vm.loadFavorites()

        #expect(vm.filteredFavorites.count == 2)
    }

    @Test func filteredFavoritesFiltersBySearchText() {
        let (_, um, vm) = makeSetup()

        um.currentUser?.favoriteSuggestions = ["Buy groceries", "Call mom", "Buy milk"]
        vm.loadFavorites()
        vm.searchText = "buy"

        #expect(vm.filteredFavorites.count == 2)
        #expect(vm.filteredFavorites.allSatisfy { $0.localizedStandardContains("buy") })
    }

    @Test func filteredFavoritesReturnsEmptyWhenNoMatch() {
        let (_, um, vm) = makeSetup()

        um.currentUser?.favoriteSuggestions = ["Buy groceries", "Call mom"]
        vm.loadFavorites()
        vm.searchText = "xyz"

        #expect(vm.filteredFavorites.isEmpty)
    }
}
