import Testing
import SwiftData
@testable import FluxList

@Suite(.serialized)
@MainActor
struct ItemFrequencyTests {
    private func makeContext() -> ModelContext {
        TestModelContainer.newContext()
    }

    // MARK: - UserManager.recordItemFrequency

    @Test func recordItemFrequencyIncrementsCount() throws {
        let context = makeContext()
        let manager = UserManager(modelContext: context)
        manager.fetchOrCreateCurrentUser()

        manager.recordItemFrequency("Milk")

        #expect(manager.currentUser?.getItemFrequencies()["milk"] == 1)
    }

    @Test func recordItemFrequencyIsCaseInsensitive() throws {
        let context = makeContext()
        let manager = UserManager(modelContext: context)
        manager.fetchOrCreateCurrentUser()

        manager.recordItemFrequency("Milk")
        manager.recordItemFrequency("milk")
        manager.recordItemFrequency("MILK")

        #expect(manager.currentUser?.getItemFrequencies()["milk"] == 3)
    }

    @Test func recordItemFrequencyAutoPromotesAtThreshold() throws {
        let context = makeContext()
        let manager = UserManager(modelContext: context)
        manager.fetchOrCreateCurrentUser()

        manager.recordItemFrequency("Eggs")
        manager.recordItemFrequency("Eggs")
        #expect(manager.currentUser?.favoriteSuggestions.isEmpty == true)

        manager.recordItemFrequency("Eggs")
        #expect(manager.currentUser?.favoriteSuggestions.contains("Eggs") == true)
    }

    @Test func recordItemFrequencyIgnoresEmptyNames() throws {
        let context = makeContext()
        let manager = UserManager(modelContext: context)
        manager.fetchOrCreateCurrentUser()

        manager.recordItemFrequency("   ")

        #expect(manager.currentUser?.getItemFrequencies().isEmpty == true)
    }

    @Test func recordItemFrequencyTrimsWhitespace() throws {
        let context = makeContext()
        let manager = UserManager(modelContext: context)
        manager.fetchOrCreateCurrentUser()

        manager.recordItemFrequency("  Bread  ")

        #expect(manager.currentUser?.getItemFrequencies()["bread"] == 1)
    }

    @Test func recordItemFrequencyDoesNotDuplicateFavorite() throws {
        let context = makeContext()
        let manager = UserManager(modelContext: context)
        manager.fetchOrCreateCurrentUser()

        // Add 6 times (well past threshold)
        for _ in 1...6 {
            manager.recordItemFrequency("Butter")
        }

        let count = manager.currentUser?.favoriteSuggestions.filter { $0 == "Butter" }.count
        #expect(count == 1)
    }
}
