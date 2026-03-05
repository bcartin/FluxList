import Testing
import SwiftData
@testable import FluxList

@Suite(.serialized)
@MainActor
struct CreateListViewModelTests {
    private func makeSetup() -> (ModelContext, CreateListViewModel) {
        let context = TestModelContainer.newContext()

        let tlm = TaskListManager(modelContext: context)
        let pm = ProjectManager(modelContext: context)
        let vm = CreateListViewModel(taskListManager: tlm, projectManager: pm)

        return (context, vm)
    }

    @Test func canSaveIsFalseWhenNameIsEmpty() throws {
        let (_, vm) = makeSetup()

        #expect(!vm.canSave)
    }

    @Test func canSaveIsFalseWhenNameIsWhitespace() throws {
        let (_, vm) = makeSetup()

        vm.name = "   "
        #expect(!vm.canSave)
    }

    @Test func canSaveIsTrueWithValidName() throws {
        let (_, vm) = makeSetup()

        vm.name = "Shopping"
        #expect(vm.canSave)
    }

    @Test func saveCreatesListWithCorrectProperties() throws {
        let (_, vm) = makeSetup()

        vm.name = "Shopping"
        vm.selectedColor = .red
        vm.selectedIcon = .cart

        let list = vm.save(createdByUserID: "user-123")

        #expect(list.name == "Shopping")
        #expect(list.colorName == "red")
        #expect(list.iconName == "cart")
        #expect(list.createdBy == "user-123")
        #expect(list.userIDs.contains("user-123"))
    }

    @Test func saveWithProject() throws {
        let (context, vm) = makeSetup()

        let project = Project(name: "Work")
        context.insert(project)

        vm.name = "Sprint Tasks"
        vm.selectedProject = project

        let list = vm.save(createdByUserID: "user-1")

        #expect(list.project?.name == "Work")
    }

    @Test func saveIncludesSharedUserIDs() throws {
        let (_, vm) = makeSetup()

        vm.name = "Team List"
        vm.sharedUserIDs = ["user-2", "user-3"]

        let list = vm.save(createdByUserID: "user-1")

        #expect(list.userIDs.contains("user-1"))
        #expect(list.userIDs.contains("user-2"))
        #expect(list.userIDs.contains("user-3"))
        #expect(list.userIDs.count == 3)
    }

    @Test func availableProjectsReturnsFetchedProjects() throws {
        let (context, vm) = makeSetup()

        let project = Project(name: "Test Project")
        context.insert(project)

        let projects = vm.availableProjects
        #expect(projects.count == 1)
        #expect(projects.first?.name == "Test Project")
    }

    @Test func addSharedUserIDAppendsOnce() throws {
        let (_, vm) = makeSetup()

        vm.addSharedUserID("user-A")
        #expect(vm.sharedUserIDs == ["user-A"])

        // Duplicate should be ignored
        vm.addSharedUserID("user-A")
        #expect(vm.sharedUserIDs == ["user-A"])

        vm.addSharedUserID("user-B")
        #expect(vm.sharedUserIDs == ["user-A", "user-B"])
    }

    @Test func removeSharedUserIDRemovesExisting() {
        let (_, vm) = makeSetup()

        vm.addSharedUserID("user-A")
        vm.addSharedUserID("user-B")
        vm.removeSharedUserID("user-A")

        #expect(vm.sharedUserIDs == ["user-B"])
    }

    @Test func removeSharedUserIDDoesNothingForUnknown() {
        let (_, vm) = makeSetup()

        vm.addSharedUserID("user-A")
        vm.removeSharedUserID("user-Z")

        #expect(vm.sharedUserIDs == ["user-A"])
    }

    @Test func isEditingIsFalseForNewList() {
        let (_, vm) = makeSetup()

        #expect(!vm.isEditing)
        #expect(vm.editingList == nil)
    }

    @Test func editingInitPopulatesFields() {
        let context = TestModelContainer.newContext()
        let tlm = TaskListManager(modelContext: context)
        let pm = ProjectManager(modelContext: context)

        let project = Project(name: "Work")
        context.insert(project)

        let list = TaskList(name: "Sprint Tasks", colorName: "red", iconName: "cart", project: project, createdBy: "user-1")
        list.userIDs = ["user-1", "user-2"]
        context.insert(list)

        let vm = CreateListViewModel(taskListManager: tlm, projectManager: pm, editing: list)

        #expect(vm.isEditing)
        #expect(vm.name == "Sprint Tasks")
        #expect(vm.selectedColor == AppColor.red)
        #expect(vm.selectedIcon == AppIcon.cart)
        #expect(vm.selectedProject?.name == "Work")
        #expect(vm.sharedUserIDs == ["user-1", "user-2"])
    }

    @Test func saveEditUpdatesExistingList() {
        let context = TestModelContainer.newContext()
        let tlm = TaskListManager(modelContext: context)
        let pm = ProjectManager(modelContext: context)

        let list = tlm.createList(name: "Original", colorName: "blue", iconName: "list.bullet", createdBy: "user-1", userIDs: ["user-1"])

        let vm = CreateListViewModel(taskListManager: tlm, projectManager: pm, editing: list)
        vm.name = "Updated"
        vm.selectedColor = AppColor.green

        let result = vm.save(createdByUserID: "user-1")

        #expect(result.id == list.id)
        #expect(result.name == "Updated")
        #expect(result.colorName == "green")
    }
}
