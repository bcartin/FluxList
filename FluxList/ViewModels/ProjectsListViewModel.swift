import Foundation

/// Drives the "Projects" management screen where the user can view, search,
/// create, rename, and delete projects.
///
/// Projects act as organizational folders that group related ``TaskList`` items.
@MainActor @Observable
final class ProjectsListViewModel {
    private let projectManager: ProjectManager

    /// All projects loaded from SwiftData.
    var projects: [Project] = []
    /// Search bar text for filtering projects by name.
    var searchText: String = ""

    /// Projects filtered by the search query (case-insensitive, locale-aware).
    var filteredProjects: [Project] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return projects }
        return projects.filter { $0.name.localizedStandardContains(query) }
    }

    // MARK: - Edit alert state

    /// Controls whether the rename alert is presented.
    var isShowingEditAlert = false
    /// The project currently being renamed.
    var editingProject: Project?
    /// The text field value inside the rename alert.
    var editedName = ""

    // MARK: - Create alert state

    /// Controls whether the "New Project" alert is presented.
    var isShowingCreateAlert = false
    /// The text field value inside the create alert.
    var newProjectName = ""

    init(projectManager: ProjectManager) {
        self.projectManager = projectManager
    }

    /// Reloads projects from SwiftData.
    func loadProjects() {
        projects = projectManager.fetchProjects()
    }

    /// Deletes a project and refreshes the list.
    func deleteProject(_ project: Project) {
        projectManager.deleteProject(project)
        loadProjects()
    }

    /// Prepares the rename alert for the given project.
    func beginEditing(_ project: Project) {
        editingProject = project
        editedName = project.name
        isShowingEditAlert = true
    }

    /// Applies the rename and refreshes the list.
    func confirmEdit() {
        guard let project = editingProject else { return }
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        projectManager.updateProject(project, name: trimmed)
        editingProject = nil
        editedName = ""
        loadProjects()
    }

    /// Prepares the "New Project" alert for presentation.
    func beginCreating() {
        newProjectName = ""
        isShowingCreateAlert = true
    }

    /// Creates the new project and refreshes the list.
    func confirmCreate() {
        let trimmed = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        projectManager.createProject(name: trimmed)
        newProjectName = ""
        loadProjects()
    }
}
