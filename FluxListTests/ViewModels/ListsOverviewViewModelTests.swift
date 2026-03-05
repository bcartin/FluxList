import Testing
import SwiftData
@testable import FluxList

@Suite(.serialized)
@MainActor
struct ListsOverviewViewModelTests {
    private func makeSetup(currentUserID: String = "user-1") -> (ModelContext, TaskListManager, ListsOverviewViewModel) {
        let context = TestModelContainer.newContext()
        let tlm = TaskListManager(modelContext: context)
        let vm = ListsOverviewViewModel(taskListManager: tlm, currentUserID: currentUserID)
        return (context, tlm, vm)
    }

    @Test func loadListsReturnsOnlyCurrentUsersLists() {
        let (_, tlm, vm) = makeSetup()

        tlm.createList(name: "My List", createdBy: "user-1")
        tlm.createList(name: "Other List", createdBy: "user-2")

        vm.loadLists()

        #expect(vm.lists.count == 1)
        #expect(vm.lists.first?.name == "My List")
    }

    @Test func filteredListsReturnsAllWhenSearchEmpty() {
        let (_, tlm, vm) = makeSetup()

        tlm.createList(name: "List A", createdBy: "user-1")
        tlm.createList(name: "List B", createdBy: "user-1")

        vm.loadLists()

        #expect(vm.filteredLists.count == 2)
    }

    @Test func filteredListsFiltersBySearchText() {
        let (_, tlm, vm) = makeSetup()

        tlm.createList(name: "Shopping", createdBy: "user-1")
        tlm.createList(name: "Work Tasks", createdBy: "user-1")

        vm.loadLists()
        vm.searchText = "shop"

        #expect(vm.filteredLists.count == 1)
        #expect(vm.filteredLists.first?.name == "Shopping")
    }

    @Test func deleteListRemovesAndReloads() {
        let (_, tlm, vm) = makeSetup()

        let list = tlm.createList(name: "Delete Me", createdBy: "user-1")
        tlm.createList(name: "Keep Me", createdBy: "user-1")

        vm.loadLists()
        #expect(vm.lists.count == 2)

        vm.deleteList(list)

        #expect(vm.lists.count == 1)
        #expect(vm.lists.first?.name == "Keep Me")
    }

    @Test func beginEditingSetsEditingList() {
        let (_, tlm, vm) = makeSetup()

        let list = tlm.createList(name: "Test", createdBy: "user-1")
        vm.beginEditing(list)

        #expect(vm.editingList?.id == list.id)
    }

    @Test func itemCountReturnsCorrectCount() {
        let (context, tlm, vm) = makeSetup()

        let list = tlm.createList(name: "Test", createdBy: "user-1")
        let item1 = ListItem(name: "Item 1", taskList: list)
        let item2 = ListItem(name: "Item 2", taskList: list)
        context.insert(item1)
        context.insert(item2)

        #expect(vm.itemCount(for: list) == 2)
    }

    @Test func completedCountReturnsCorrectCount() {
        let (context, tlm, vm) = makeSetup()

        let list = tlm.createList(name: "Test", createdBy: "user-1")
        let done = ListItem(name: "Done", isCompleted: true, taskList: list)
        let active = ListItem(name: "Active", isCompleted: false, taskList: list)
        context.insert(done)
        context.insert(active)

        #expect(vm.completedCount(for: list) == 1)
    }
}
