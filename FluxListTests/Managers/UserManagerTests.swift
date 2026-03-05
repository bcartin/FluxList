import Testing
import Foundation
import SwiftData
@testable import FluxList

@Suite(.serialized)
@MainActor
struct UserManagerTests {
    private func makeContext() -> ModelContext {
        TestModelContainer.newContext()
    }

    @Test func fetchOrCreateCurrentUserCreatesNewUser() throws {
        let context = makeContext()
        let manager = UserManager(modelContext: context)

        manager.fetchOrCreateCurrentUser()

        #expect(manager.currentUser != nil)
        #expect(manager.currentUser?.name == "Me")
    }

    @Test func fetchOrCreateCurrentUserReturnsExisting() throws {
        let context = makeContext()
        let existingUser = User(name: "Robert", email: "robert@example.com")
        context.insert(existingUser)

        let manager = UserManager(modelContext: context)
        manager.fetchOrCreateCurrentUser()

        #expect(manager.currentUser?.name == "Robert")
        #expect(manager.currentUser?.email == "robert@example.com")
    }

    @Test func updateUser() throws {
        let context = makeContext()
        let manager = UserManager(modelContext: context)
        manager.fetchOrCreateCurrentUser()

        manager.updateUser(name: "Bernie", email: "bernie@test.com")

        #expect(manager.currentUser?.name == "Bernie")
        #expect(manager.currentUser?.email == "bernie@test.com")
    }

    @Test func toggleFavoriteAddsAndRemoves() throws {
        let context = makeContext()
        let manager = UserManager(modelContext: context)
        manager.fetchOrCreateCurrentUser()

        let list = TaskList(name: "Test List")
        context.insert(list)

        manager.toggleFavorite(list: list)
        #expect(manager.isFavorite(list: list))

        manager.toggleFavorite(list: list)
        #expect(!manager.isFavorite(list: list))
    }

    // MARK: - Favorite Suggestions

    @Test func addFavoriteSuggestion() throws {
        let context = makeContext()
        let manager = UserManager(modelContext: context)
        manager.fetchOrCreateCurrentUser()

        manager.addFavoriteSuggestion("Buy groceries")

        #expect(manager.currentUser?.favoriteSuggestions == ["Buy groceries"])
    }

    @Test func addFavoriteSuggestionTrimsList() throws {
        let context = makeContext()
        let manager = UserManager(modelContext: context)
        manager.fetchOrCreateCurrentUser()

        manager.addFavoriteSuggestion("  Call mom  ")

        #expect(manager.currentUser?.favoriteSuggestions == ["Call mom"])
    }

    @Test func addFavoriteSuggestionIgnoresEmpty() throws {
        let context = makeContext()
        let manager = UserManager(modelContext: context)
        manager.fetchOrCreateCurrentUser()

        manager.addFavoriteSuggestion("   ")

        #expect(manager.currentUser?.favoriteSuggestions.isEmpty == true)
    }

    @Test func addFavoriteSuggestionIgnoresDuplicates() throws {
        let context = makeContext()
        let manager = UserManager(modelContext: context)
        manager.fetchOrCreateCurrentUser()

        manager.addFavoriteSuggestion("Task")
        manager.addFavoriteSuggestion("Task")

        #expect(manager.currentUser?.favoriteSuggestions.count == 1)
    }

    @Test func removeFavoriteSuggestionAtIndex() throws {
        let context = makeContext()
        let manager = UserManager(modelContext: context)
        manager.fetchOrCreateCurrentUser()

        manager.addFavoriteSuggestion("A")
        manager.addFavoriteSuggestion("B")
        manager.addFavoriteSuggestion("C")

        manager.removeFavoriteSuggestion(at: 1)

        #expect(manager.currentUser?.favoriteSuggestions == ["A", "C"])
    }

    @Test func removeFavoriteSuggestionIgnoresInvalidIndex() throws {
        let context = makeContext()
        let manager = UserManager(modelContext: context)
        manager.fetchOrCreateCurrentUser()

        manager.addFavoriteSuggestion("A")

        manager.removeFavoriteSuggestion(at: 5)

        #expect(manager.currentUser?.favoriteSuggestions == ["A"])
    }

    // MARK: - Friends

    @Test func addFriendAppendsFriendID() {
        let context = makeContext()
        let manager = UserManager(modelContext: context)
        manager.fetchOrCreateCurrentUser()

        manager.addFriend("friend-1")

        #expect(manager.currentUser?.friends == ["friend-1"])
    }

    @Test func addFriendIgnoresDuplicates() {
        let context = makeContext()
        let manager = UserManager(modelContext: context)
        manager.fetchOrCreateCurrentUser()

        manager.addFriend("friend-1")
        manager.addFriend("friend-1")

        #expect(manager.currentUser?.friends.count == 1)
    }

    @Test func removeFriendRemovesExisting() {
        let context = makeContext()
        let manager = UserManager(modelContext: context)
        manager.fetchOrCreateCurrentUser()

        manager.addFriend("friend-1")
        manager.addFriend("friend-2")
        manager.removeFriend("friend-1")

        #expect(manager.currentUser?.friends == ["friend-2"])
    }

    @Test func removeFriendDoesNothingForUnknownID() {
        let context = makeContext()
        let manager = UserManager(modelContext: context)
        manager.fetchOrCreateCurrentUser()

        manager.addFriend("friend-1")
        manager.removeFriend("unknown")

        #expect(manager.currentUser?.friends == ["friend-1"])
    }

    // MARK: - Display Name Resolution

    @Test func displayNameReturnsNilForUnknownID() {
        let context = makeContext()
        let manager = UserManager(modelContext: context)

        #expect(manager.displayName(for: "unknown") == nil)
    }

    @Test func resolveUserNamesResolvesCurrentUserByStableID() {
        let context = makeContext()
        let manager = UserManager(modelContext: context)
        manager.fetchOrCreateCurrentUser()

        let stableID = manager.currentUser!.stableID
        manager.resolveUserNames(for: [stableID])

        #expect(manager.displayName(for: stableID) == "Me")
    }

    @Test func resolveUserNamesResolvesCurrentUserByLocalUUID() {
        let context = makeContext()
        let manager = UserManager(modelContext: context)
        manager.fetchOrCreateCurrentUser()

        let localID = manager.currentUser!.id.uuidString
        manager.resolveUserNames(for: [localID])

        #expect(manager.displayName(for: localID) == "Me")
    }

    @Test func resolveUserNamesSkipsAlreadyCached() {
        let context = makeContext()
        let manager = UserManager(modelContext: context)
        manager.fetchOrCreateCurrentUser()

        let stableID = manager.currentUser!.stableID
        manager.resolveUserNames(for: [stableID])
        #expect(manager.displayName(for: stableID) == "Me")

        // Change user name after caching
        manager.currentUser?.name = "Changed"
        manager.resolveUserNames(for: [stableID])

        // Should still return cached value
        #expect(manager.displayName(for: stableID) == "Me")
    }

    // MARK: - isFavorite edge case

    @Test func isFavoriteReturnsFalseWhenNoCurrentUser() {
        let context = makeContext()
        let manager = UserManager(modelContext: context)
        // Don't call fetchOrCreateCurrentUser

        let list = TaskList(name: "Test")
        context.insert(list)

        #expect(!manager.isFavorite(list: list))
    }
}
