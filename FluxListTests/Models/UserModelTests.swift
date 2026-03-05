import Testing
import Foundation
import SwiftData
@testable import FluxList

@Suite(.serialized)
@MainActor
struct UserModelTests {
    private func makeContext() -> ModelContext {
        TestModelContainer.newContext()
    }

    // MARK: - stableID

    @Test func stableIDReturnsFirebaseUIDWhenAvailable() {
        let user = User(name: "Test", email: "test@example.com", firebaseUID: "firebase-123")

        #expect(user.stableID == "firebase-123")
    }

    @Test func stableIDFallsBackToLocalUUID() {
        let user = User(name: "Test", email: "test@example.com")

        #expect(user.stableID == user.id.uuidString)
    }

    // MARK: - Item Frequencies

    @Test func getItemFrequenciesReturnsEmptyWhenNoData() {
        let user = User(name: "Test", email: "")

        #expect(user.getItemFrequencies().isEmpty)
    }

    @Test func setAndGetItemFrequenciesRoundTrips() {
        let user = User(name: "Test", email: "")
        let frequencies = ["milk": 3, "eggs": 1, "bread": 5]

        user.setItemFrequencies(frequencies)

        #expect(user.getItemFrequencies() == frequencies)
    }

    @Test func setItemFrequenciesOverwritesPrevious() {
        let user = User(name: "Test", email: "")

        user.setItemFrequencies(["old": 10])
        user.setItemFrequencies(["new": 1])

        #expect(user.getItemFrequencies() == ["new": 1])
    }

    @Test func setEmptyFrequenciesClearsData() {
        let user = User(name: "Test", email: "")

        user.setItemFrequencies(["something": 5])
        user.setItemFrequencies([:])

        #expect(user.getItemFrequencies().isEmpty)
    }

    // MARK: - Default values

    @Test func newUserHasEmptyDefaults() {
        let user = User(name: "Test", email: "test@example.com")

        #expect(user.favoriteListIDs.isEmpty)
        #expect(user.favoriteSuggestions.isEmpty)
        #expect(user.friends.isEmpty)
        #expect(user.firebaseUID == nil)
    }
}
