import Testing
import SwiftData
@testable import FluxList

@Suite(.serialized)
@MainActor
struct ProjectManagerTests {
    private func makeContext() -> ModelContext {
        TestModelContainer.newContext()
    }

    @Test func createProject() throws {
        let context = makeContext()
        let manager = ProjectManager(modelContext: context)

        let project = manager.createProject(name: "Work")

        #expect(project.name == "Work")
    }

    @Test func fetchProjects() throws {
        let context = makeContext()
        let manager = ProjectManager(modelContext: context)

        manager.createProject(name: "Work")
        manager.createProject(name: "Personal")

        let projects = manager.fetchProjects()
        #expect(projects.count == 2)
    }

    @Test func deleteProject() throws {
        let context = makeContext()
        let manager = ProjectManager(modelContext: context)

        let project = manager.createProject(name: "Delete Me")
        manager.deleteProject(project)

        let projects = manager.fetchProjects()
        #expect(projects.isEmpty)
    }

    @Test func updateProject() throws {
        let context = makeContext()
        let manager = ProjectManager(modelContext: context)

        let project = manager.createProject(name: "Old Name")
        manager.updateProject(project, name: "New Name")

        #expect(project.name == "New Name")
    }
}
