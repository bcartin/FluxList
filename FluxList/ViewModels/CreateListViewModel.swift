import Foundation
import SwiftData

/// Backs the "Create / Edit List" sheet, holding form state (name, color, icon,
/// project, shared users) and performing the save through ``TaskListManager``.
///
/// Supports two modes:
/// - **Create** – when initialized without an existing list.
/// - **Edit** – when initialized with an existing ``TaskList`` via the
///   `editing:` parameter; form fields are pre-populated from the list.
@MainActor @Observable
final class CreateListViewModel {
    /// The name the user has typed into the text field.
    var name: String = ""
    /// The color chosen from the ``AppColor`` palette.
    var selectedColor: AppColor = .blue
    /// The SF Symbol icon chosen from the ``AppIcon`` set.
    var selectedIcon: AppIcon = .listBullet
    /// The project the list will be grouped under (optional).
    var selectedProject: Project?
    /// `stableID` values of users this list will be shared with.
    var sharedUserIDs: [String] = []

    /// The list being edited, or `nil` when creating a new list.
    private(set) var editingList: TaskList?

    /// `true` when the sheet is in edit mode (as opposed to create mode).
    var isEditing: Bool { editingList != nil }

    private let taskListManager: TaskListManager
    private let projectManager: ProjectManager

    /// All projects available for assigning this list to.
    var availableProjects: [Project] {
        projectManager.fetchProjects()
    }

    /// Whether the form has enough data to save (non-empty name).
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Initializer for **creating** a new list.
    init(taskListManager: TaskListManager, projectManager: ProjectManager) {
        self.taskListManager = taskListManager
        self.projectManager = projectManager
    }

    /// Initializer for **editing** an existing list. Pre-populates all form fields.
    init(taskListManager: TaskListManager, projectManager: ProjectManager, editing list: TaskList) {
        self.taskListManager = taskListManager
        self.projectManager = projectManager
        self.editingList = list
        self.name = list.name
        self.selectedColor = AppColor(rawValue: list.colorName) ?? .blue
        self.selectedIcon = AppIcon(rawValue: list.iconName) ?? .listBullet
        self.selectedProject = list.project
        self.sharedUserIDs = list.userIDs
    }

    /// Persists the list — either updating the existing one or creating a new one.
    /// Ensures the creator's `stableID` is always included in ``TaskList/userIDs``.
    @discardableResult
    func save(createdByUserID: String) -> TaskList {
        if let editingList {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            taskListManager.updateList(
                editingList,
                name: trimmed,
                colorName: selectedColor.rawValue,
                iconName: selectedIcon.rawValue,
                project: selectedProject
            )
            editingList.userIDs = sharedUserIDs
            // Ensure the creator always has access to their own list.
            if !editingList.userIDs.contains(createdByUserID) {
                editingList.userIDs.insert(createdByUserID, at: 0)
            }
            return editingList
        }

        // Create new list, inserting the creator at the front of the user IDs.
        var allUserIDs = sharedUserIDs
        if !allUserIDs.contains(createdByUserID) {
            allUserIDs.insert(createdByUserID, at: 0)
        }

        let list = taskListManager.createList(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            colorName: selectedColor.rawValue,
            iconName: selectedIcon.rawValue,
            project: selectedProject,
            createdBy: createdByUserID,
            userIDs: allUserIDs
        )
        return list
    }

    /// Adds a user to the shared list (no-op if already present).
    func addSharedUserID(_ userID: String) {
        guard !sharedUserIDs.contains(userID) else { return }
        sharedUserIDs.append(userID)
    }

    /// Removes a user from the shared list.
    func removeSharedUserID(_ userID: String) {
        sharedUserIDs.removeAll { $0 == userID }
    }
}
