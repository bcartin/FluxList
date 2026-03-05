import Testing
import SwiftData
@testable import FluxList

@Suite(.serialized)
@MainActor
struct ProjectsListViewModelTests {
    private func makeSetup() -> (ModelContext, ProjectManager, ProjectsListViewModel) {
        let context = TestModelContainer.newContext()
        let pm = ProjectManager(modelContext: context)
        let vm = ProjectsListViewModel(projectManager: pm)
        return (context, pm, vm)
    }

    @Test func loadProjectsFetchesAll() {
        let (_, pm, vm) = makeSetup()

        pm.createProject(name: "Work")
        pm.createProject(name: "Personal")

        vm.loadProjects()

        #expect(vm.projects.count == 2)
    }

    @Test func filteredProjectsReturnsAllWhenSearchEmpty() {
        let (_, pm, vm) = makeSetup()

        pm.createProject(name: "Work")
        pm.createProject(name: "Home")

        vm.loadProjects()

        #expect(vm.filteredProjects.count == 2)
    }

    @Test func filteredProjectsFiltersBySearchText() {
        let (_, pm, vm) = makeSetup()

        pm.createProject(name: "Work")
        pm.createProject(name: "Home")

        vm.loadProjects()
        vm.searchText = "work"

        #expect(vm.filteredProjects.count == 1)
        #expect(vm.filteredProjects.first?.name == "Work")
    }

    @Test func deleteProjectRemovesAndReloads() {
        let (_, pm, vm) = makeSetup()

        let project = pm.createProject(name: "Delete Me")
        pm.createProject(name: "Keep Me")

        vm.loadProjects()
        #expect(vm.projects.count == 2)

        vm.deleteProject(project)

        #expect(vm.projects.count == 1)
        #expect(vm.projects.first?.name == "Keep Me")
    }

    @Test func beginEditingSetsStateCorrectly() {
        let (_, pm, vm) = makeSetup()

        let project = pm.createProject(name: "Work")
        vm.beginEditing(project)

        #expect(vm.editingProject?.id == project.id)
        #expect(vm.editedName == "Work")
        #expect(vm.isShowingEditAlert)
    }

    @Test func confirmEditUpdatesProjectName() {
        let (_, pm, vm) = makeSetup()

        let project = pm.createProject(name: "Old Name")
        vm.loadProjects()

        vm.beginEditing(project)
        vm.editedName = "New Name"
        vm.confirmEdit()

        #expect(project.name == "New Name")
        #expect(vm.editingProject == nil)
        #expect(vm.editedName.isEmpty)
    }

    @Test func confirmEditIgnoresEmptyName() {
        let (_, pm, vm) = makeSetup()

        let project = pm.createProject(name: "Keep This")
        vm.loadProjects()

        vm.beginEditing(project)
        vm.editedName = "   "
        vm.confirmEdit()

        #expect(project.name == "Keep This")
    }

    @Test func beginCreatingResetsNameAndShowsAlert() {
        let (_, _, vm) = makeSetup()

        vm.newProjectName = "leftover"
        vm.beginCreating()

        #expect(vm.newProjectName.isEmpty)
        #expect(vm.isShowingCreateAlert)
    }

    @Test func confirmCreateAddsProjectAndReloads() {
        let (_, _, vm) = makeSetup()

        vm.loadProjects()
        vm.newProjectName = "New Project"
        vm.confirmCreate()

        #expect(vm.projects.count == 1)
        #expect(vm.projects.first?.name == "New Project")
        #expect(vm.newProjectName.isEmpty)
    }

    @Test func confirmCreateIgnoresEmptyName() {
        let (_, _, vm) = makeSetup()

        vm.loadProjects()
        vm.newProjectName = "   "
        vm.confirmCreate()

        #expect(vm.projects.isEmpty)
    }
}
