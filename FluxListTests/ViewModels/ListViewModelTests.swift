import Testing
import SwiftData
@testable import FluxList

@Suite(.serialized)
@MainActor
struct ListViewModelTests {
    private func makeSetup() -> (ModelContext, ListItemManager) {
        let context = TestModelContainer.newContext()
        let lim = ListItemManager(modelContext: context)
        return (context, lim)
    }

    @Test func deleteCompletedItemsRemovesOnlyCompleted() throws {
        let (context, lim) = makeSetup()

        let list = TaskList(name: "Test")
        context.insert(list)

        let done1 = ListItem(name: "Done 1", isCompleted: true, taskList: list)
        let done2 = ListItem(name: "Done 2", isCompleted: true, taskList: list)
        let active = ListItem(name: "Active", isCompleted: false, taskList: list)
        [done1, done2, active].forEach { context.insert($0) }

        let vm = ListViewModel(taskList: list, listItemManager: lim)
        vm.deleteCompletedItems()

        #expect(list.items?.count == 1)
        #expect(list.items?.first?.name == "Active")
    }

    @Test func deleteCompletedItemsDoesNothingWhenNoneCompleted() throws {
        let (context, lim) = makeSetup()

        let list = TaskList(name: "Test")
        context.insert(list)

        let item1 = ListItem(name: "Task 1", isCompleted: false, taskList: list)
        let item2 = ListItem(name: "Task 2", isCompleted: false, taskList: list)
        [item1, item2].forEach { context.insert($0) }

        let vm = ListViewModel(taskList: list, listItemManager: lim)
        vm.deleteCompletedItems()

        #expect(list.items?.count == 2)
    }

    @Test func deleteCompletedItemsRemovesAllWhenAllCompleted() throws {
        let (context, lim) = makeSetup()

        let list = TaskList(name: "Test")
        context.insert(list)

        let done1 = ListItem(name: "Done 1", isCompleted: true, taskList: list)
        let done2 = ListItem(name: "Done 2", isCompleted: true, taskList: list)
        [done1, done2].forEach { context.insert($0) }

        let vm = ListViewModel(taskList: list, listItemManager: lim)
        vm.deleteCompletedItems()

        #expect(list.items?.isEmpty == true)
    }

    @Test func addItemClearsNewItemName() throws {
        let (context, lim) = makeSetup()

        let list = TaskList(name: "Test")
        context.insert(list)

        let vm = ListViewModel(taskList: list, listItemManager: lim)
        vm.newItemName = "New task"
        vm.addItem(createdBy: "user-123")

        #expect(vm.newItemName.isEmpty)
        #expect(list.items?.count == 1)
        #expect(list.items?.first?.name == "New task")
    }

    @Test func addItemDoesNothingWhenEmpty() throws {
        let (context, lim) = makeSetup()

        let list = TaskList(name: "Test")
        context.insert(list)

        let vm = ListViewModel(taskList: list, listItemManager: lim)
        vm.newItemName = "   "
        vm.addItem(createdBy: "user-123")

        #expect(list.items?.isEmpty != false)
    }

    @Test func sortedItemsPlacesIncompleteFirst() throws {
        let (context, lim) = makeSetup()

        let list = TaskList(name: "Test")
        context.insert(list)

        let completed = ListItem(name: "Completed", isCompleted: true, taskList: list)
        let active = ListItem(name: "Active", isCompleted: false, taskList: list)
        [completed, active].forEach { context.insert($0) }

        let vm = ListViewModel(taskList: list, listItemManager: lim)

        #expect(vm.sortedItems.first?.name == "Active")
        #expect(vm.sortedItems.last?.name == "Completed")
    }

    @Test func canAddItemIsTrueWithText() {
        let (context, lim) = makeSetup()

        let list = TaskList(name: "Test")
        context.insert(list)

        let vm = ListViewModel(taskList: list, listItemManager: lim)
        vm.newItemName = "Something"

        #expect(vm.canAddItem)
    }

    @Test func canAddItemIsFalseWhenWhitespaceOnly() {
        let (context, lim) = makeSetup()

        let list = TaskList(name: "Test")
        context.insert(list)

        let vm = ListViewModel(taskList: list, listItemManager: lim)
        vm.newItemName = "   "

        #expect(!vm.canAddItem)
    }

    @Test func toggleCompletionTogglesItemState() {
        let (context, lim) = makeSetup()

        let list = TaskList(name: "Test")
        context.insert(list)

        let item = ListItem(name: "Task", isCompleted: false, taskList: list)
        context.insert(item)

        let vm = ListViewModel(taskList: list, listItemManager: lim)
        vm.toggleCompletion(item)

        #expect(item.isCompleted)
    }

    @Test func deleteItemRemovesFromList() {
        let (context, lim) = makeSetup()

        let list = TaskList(name: "Test")
        context.insert(list)

        let item = ListItem(name: "Delete me", taskList: list)
        context.insert(item)

        let vm = ListViewModel(taskList: list, listItemManager: lim)
        vm.deleteItem(item)

        let items = lim.fetchItems(for: list)
        #expect(items.isEmpty)
    }

    @Test func addItemTrimsWhitespace() {
        let (context, lim) = makeSetup()

        let list = TaskList(name: "Test")
        context.insert(list)

        let vm = ListViewModel(taskList: list, listItemManager: lim)
        vm.newItemName = "  Trimmed  "
        vm.addItem(createdBy: "user-1")

        #expect(list.items?.first?.name == "Trimmed")
    }
}
