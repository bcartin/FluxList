import Testing
import SwiftData
@testable import FluxList

@Suite(.serialized)
@MainActor
struct HomeViewModelTests {
    private func makeSetup() -> (ModelContext, HomeViewModel) {
        let context = TestModelContainer.newContext()

        let tlm = TaskListManager(modelContext: context)
        let pm = ProjectManager(modelContext: context)
        let lim = ListItemManager(modelContext: context)
        let vm = HomeViewModel(taskListManager: tlm, projectManager: pm, listItemManager: lim)

        return (context, vm)
    }

    @Test func filteredListsReturnsAllByDefault() throws {
        let (context, vm) = makeSetup()

        let list1 = TaskList(name: "List 1")
        let list2 = TaskList(name: "List 2")
        context.insert(list1)
        context.insert(list2)

        vm.loadData()

        #expect(vm.filteredLists.count == 2)
        #expect(vm.filterLabel == "All")
    }

    @Test func filteredListsByProject() throws {
        let (context, vm) = makeSetup()

        let project = Project(name: "Work")
        context.insert(project)

        let workList = TaskList(name: "Work List", project: project)
        let personalList = TaskList(name: "Personal List")
        context.insert(workList)
        context.insert(personalList)

        vm.loadData()
        vm.selectProject(project)

        #expect(vm.filteredLists.count == 1)
        #expect(vm.filteredLists.first?.name == "Work List")
        #expect(vm.filterLabel == "Work")
    }

    @Test func selectAllResetsFilter() throws {
        let (context, vm) = makeSetup()

        let project = Project(name: "Work")
        context.insert(project)

        let list = TaskList(name: "Test", project: project)
        context.insert(list)

        vm.loadData()
        vm.selectProject(project)
        vm.selectAll()

        #expect(vm.selectedProject == nil)
        #expect(vm.selectedList == nil)
        #expect(vm.filterLabel == "All")
    }

    @Test func toggleExpansion() throws {
        let (context, vm) = makeSetup()

        let list = TaskList(name: "Test")
        context.insert(list)

        vm.loadData()

        // Should be expanded by default after loadData
        #expect(vm.isExpanded(list))

        vm.toggleExpansion(for: list)
        #expect(!vm.isExpanded(list))

        vm.toggleExpansion(for: list)
        #expect(vm.isExpanded(list))
    }

    @Test func selectListFiltersSingle() throws {
        let (context, vm) = makeSetup()

        let list1 = TaskList(name: "List 1")
        let list2 = TaskList(name: "List 2")
        context.insert(list1)
        context.insert(list2)

        vm.loadData()
        vm.selectList(list1)

        #expect(vm.filteredLists.count == 1)
        #expect(vm.filteredLists.first?.name == "List 1")
        #expect(vm.filterLabel == "List 1")
    }

    // MARK: - isFilteringToSingleList

    @Test func isFilteringToSingleListIsFalseByDefault() throws {
        let (_, vm) = makeSetup()

        #expect(!vm.isFilteringToSingleList)
    }

    @Test func isFilteringToSingleListIsTrueWhenListSelected() throws {
        let (context, vm) = makeSetup()

        let list = TaskList(name: "Personal")
        context.insert(list)

        vm.loadData()
        vm.selectList(list)

        #expect(vm.isFilteringToSingleList)
    }

    @Test func isFilteringToSingleListIsFalseWhenProjectSelected() throws {
        let (context, vm) = makeSetup()

        let project = Project(name: "Work")
        context.insert(project)
        let list = TaskList(name: "Sprint Tasks", project: project)
        context.insert(list)

        vm.loadData()
        vm.selectProject(project)

        #expect(!vm.isFilteringToSingleList)
    }

    @Test func isFilteringToSingleListIsFalseAfterSelectAll() throws {
        let (context, vm) = makeSetup()

        let list = TaskList(name: "Personal")
        context.insert(list)

        vm.loadData()
        vm.selectList(list)
        #expect(vm.isFilteringToSingleList)

        vm.selectAll()
        #expect(!vm.isFilteringToSingleList)
    }

    // MARK: - Filter mutual exclusion

    @Test func selectListClearsSelectedProject() throws {
        let (context, vm) = makeSetup()

        let project = Project(name: "Work")
        context.insert(project)
        let list = TaskList(name: "Personal")
        context.insert(list)

        vm.loadData()
        vm.selectProject(project)
        #expect(vm.selectedProject != nil)

        vm.selectList(list)
        #expect(vm.selectedProject == nil)
        #expect(vm.selectedList != nil)
    }

    @Test func selectProjectClearsSelectedList() throws {
        let (context, vm) = makeSetup()

        let project = Project(name: "Work")
        context.insert(project)
        let list = TaskList(name: "Personal")
        context.insert(list)

        vm.loadData()
        vm.selectList(list)
        #expect(vm.selectedList != nil)

        vm.selectProject(project)
        #expect(vm.selectedList == nil)
        #expect(vm.selectedProject != nil)
    }

    // MARK: - Clear completed

    @Test func clearCompletedRemovesCompletedItemsFromAllFilteredLists() throws {
        let (context, vm) = makeSetup()

        let list1 = TaskList(name: "List 1")
        let list2 = TaskList(name: "List 2")
        context.insert(list1)
        context.insert(list2)

        let item1 = ListItem(name: "Done 1", isCompleted: true, taskList: list1)
        let item2 = ListItem(name: "Not done", isCompleted: false, taskList: list1)
        let item3 = ListItem(name: "Done 2", isCompleted: true, taskList: list2)
        let item4 = ListItem(name: "Active", isCompleted: false, taskList: list2)
        [item1, item2, item3, item4].forEach { context.insert($0) }

        vm.loadData()
        vm.clearCompleted()

        #expect(list1.items?.count == 1)
        #expect(list1.items?.first?.name == "Not done")
        #expect(list2.items?.count == 1)
        #expect(list2.items?.first?.name == "Active")
    }

    @Test func clearCompletedOnlyAffectsFilteredLists() throws {
        let (context, vm) = makeSetup()

        let project = Project(name: "Work")
        context.insert(project)

        let workList = TaskList(name: "Work List", project: project)
        let personalList = TaskList(name: "Personal")
        context.insert(workList)
        context.insert(personalList)

        let workDone = ListItem(name: "Work done", isCompleted: true, taskList: workList)
        let personalDone = ListItem(name: "Personal done", isCompleted: true, taskList: personalList)
        context.insert(workDone)
        context.insert(personalDone)

        vm.loadData()
        vm.selectProject(project)
        vm.clearCompleted()

        // Work list's completed item should be removed
        #expect(workList.items?.isEmpty == true)
        // Personal list's completed item should remain (not in filtered lists)
        #expect(personalList.items?.count == 1)
    }

    @Test func clearCompletedDoesNothingWhenNoCompletedItems() throws {
        let (context, vm) = makeSetup()

        let list = TaskList(name: "Test")
        context.insert(list)

        let item = ListItem(name: "Active", isCompleted: false, taskList: list)
        context.insert(item)

        vm.loadData()
        vm.clearCompleted()

        #expect(list.items?.count == 1)
    }
}
