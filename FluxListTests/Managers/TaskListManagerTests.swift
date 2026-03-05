import Testing
import SwiftData
@testable import FluxList

@Suite(.serialized)
@MainActor
struct TaskListManagerTests {
    private func makeContext() -> ModelContext {
        TestModelContainer.newContext()
    }

    @Test func createList() throws {
        let context = makeContext()
        let manager = TaskListManager(modelContext: context)

        let list = manager.createList(name: "Shopping", colorName: "red", iconName: "cart")

        #expect(list.name == "Shopping")
        #expect(list.colorName == "red")
        #expect(list.iconName == "cart")
    }

    @Test func fetchAllLists() throws {
        let context = makeContext()
        let manager = TaskListManager(modelContext: context)

        manager.createList(name: "List 1")
        manager.createList(name: "List 2")

        let lists = manager.fetchAllLists()
        #expect(lists.count == 2)
    }

    @Test func deleteList() throws {
        let context = makeContext()
        let manager = TaskListManager(modelContext: context)

        let list = manager.createList(name: "Delete Me")
        manager.deleteList(list)

        let lists = manager.fetchAllLists()
        #expect(lists.isEmpty)
    }

    @Test func updateList() throws {
        let context = makeContext()
        let manager = TaskListManager(modelContext: context)

        let list = manager.createList(name: "Old", colorName: "blue")
        manager.updateList(list, name: "New", colorName: "red")

        #expect(list.name == "New")
        #expect(list.colorName == "red")
    }

    @Test func createListWithProject() throws {
        let context = makeContext()
        let manager = TaskListManager(modelContext: context)
        let project = Project(name: "Work")
        context.insert(project)

        let list = manager.createList(name: "Sprint Tasks", project: project)

        #expect(list.project?.name == "Work")
    }

    @Test func addAndRemoveUserID() throws {
        let context = makeContext()
        let manager = TaskListManager(modelContext: context)

        let list = manager.createList(name: "Shared List")

        manager.addUserID("user-123", to: list)
        #expect(list.userIDs.count == 1)
        #expect(list.userIDs.contains("user-123"))

        // Adding same ID again should not duplicate
        manager.addUserID("user-123", to: list)
        #expect(list.userIDs.count == 1)

        manager.removeUserID("user-123", from: list)
        #expect(list.userIDs.isEmpty)
    }

    @Test func createListWithUserIDs() throws {
        let context = makeContext()
        let manager = TaskListManager(modelContext: context)

        let list = manager.createList(
            name: "Team List",
            createdBy: "user-1",
            userIDs: ["user-1", "user-2", "user-3"]
        )

        #expect(list.createdBy == "user-1")
        #expect(list.userIDs.count == 3)
    }

    @Test func fetchListsForUser() throws {
        let context = makeContext()
        let manager = TaskListManager(modelContext: context)

        manager.createList(name: "List A", userIDs: ["user-1", "user-2"])
        manager.createList(name: "List B", userIDs: ["user-2"])
        manager.createList(name: "List C", userIDs: ["user-3"])

        let user2Lists = manager.fetchLists(for: "user-2")
        #expect(user2Lists.count == 2)
    }

    @Test func fetchListsForProject() throws {
        let context = makeContext()
        let manager = TaskListManager(modelContext: context)

        let project = Project(name: "Work")
        context.insert(project)

        manager.createList(name: "Work Task", project: project)
        manager.createList(name: "Personal Task")

        let workLists = manager.fetchLists(for: project)
        #expect(workLists.count == 1)
        #expect(workLists.first?.name == "Work Task")
    }

    @Test func updateListIconName() throws {
        let context = makeContext()
        let manager = TaskListManager(modelContext: context)

        let list = manager.createList(name: "Test", iconName: "list.bullet")
        manager.updateList(list, iconName: "cart")

        #expect(list.iconName == "cart")
        #expect(list.name == "Test") // unchanged
    }
}
