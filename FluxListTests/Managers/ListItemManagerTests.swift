import Testing
import SwiftData
@testable import FluxList

@Suite(.serialized)
@MainActor
struct ListItemManagerTests {
    private func makeContext() -> ModelContext {
        TestModelContainer.newContext()
    }

    @Test func createItem() throws {
        let context = makeContext()
        let manager = ListItemManager(modelContext: context)
        let list = TaskList(name: "Test List")
        context.insert(list)

        let item = manager.createItem(name: "Buy groceries", createdBy: "user-123", in: list)

        #expect(item.name == "Buy groceries")
        #expect(item.createdBy == "user-123")
        #expect(item.isCompleted == false)
        #expect(item.taskList?.id == list.id)
    }

    @Test func toggleCompletion() throws {
        let context = makeContext()
        let manager = ListItemManager(modelContext: context)
        let list = TaskList(name: "Test List")
        context.insert(list)

        let item = manager.createItem(name: "Task", in: list)

        #expect(item.isCompleted == false)
        manager.toggleCompletion(item)
        #expect(item.isCompleted == true)
        manager.toggleCompletion(item)
        #expect(item.isCompleted == false)
    }

    @Test func deleteItem() throws {
        let context = makeContext()
        let manager = ListItemManager(modelContext: context)
        let list = TaskList(name: "Test List")
        context.insert(list)

        let item = manager.createItem(name: "Delete Me", in: list)
        manager.deleteItem(item)

        let items = manager.fetchItems(for: list)
        #expect(items.isEmpty)
    }

    @Test func updateItem() throws {
        let context = makeContext()
        let manager = ListItemManager(modelContext: context)
        let list = TaskList(name: "Test List")
        context.insert(list)

        let item = manager.createItem(name: "Old Name", in: list)
        manager.updateItem(item, name: "New Name")

        #expect(item.name == "New Name")
    }

    @Test func fetchItemsReturnsCorrectList() throws {
        let context = makeContext()
        let manager = ListItemManager(modelContext: context)
        let list1 = TaskList(name: "List 1")
        let list2 = TaskList(name: "List 2")
        context.insert(list1)
        context.insert(list2)

        manager.createItem(name: "Item A", in: list1)
        manager.createItem(name: "Item B", in: list1)
        manager.createItem(name: "Item C", in: list2)

        let items1 = manager.fetchItems(for: list1)
        let items2 = manager.fetchItems(for: list2)

        #expect(items1.count == 2)
        #expect(items2.count == 1)
    }
}
