import Foundation
import SwiftData

/// The main view model for the home screen, responsible for loading all lists
/// and projects, managing which ones are visible (via filter and expansion state),
/// and providing batch operations like clearing completed items.
///
/// Injected into the environment so child views (``ViewFilterMenu``,
/// ``ListCardView``, etc.) can read and modify the shared state.
@MainActor @Observable
final class HomeViewModel {
    private let taskListManager: TaskListManager
    private let projectManager: ProjectManager
    private let listItemManager: ListItemManager

    /// Every task list in the store, loaded by ``loadData()``.
    var allLists: [TaskList] = []
    /// Every project in the store, loaded by ``loadData()``.
    var allProjects: [Project] = []
    /// Tracks which list cards are expanded to show their items on the home screen.
    var expandedListIDs: Set<UUID> = []

    // MARK: - Filter state (driven by ViewFilterMenu)

    /// The project currently selected in the filter menu, or `nil` for "All".
    var selectedProject: Project?
    /// The single list currently selected in the filter menu, or `nil`.
    var selectedList: TaskList?
    /// The label displayed on the filter pill (e.g. "All", a project name, or a list name).
    var filterLabel: String = "All"

    /// When true, a single list is selected and the home view should show
    /// an inline list-detail layout instead of the multi-card overview.
    var isFilteringToSingleList: Bool {
        selectedList != nil
    }

    /// The lists that match the current filter selection.
    var filteredLists: [TaskList] {
        if let selectedList {
            return [selectedList]
        }
        if let selectedProject {
            return allLists.filter { $0.project?.id == selectedProject.id }
        }
        return allLists
    }

    init(taskListManager: TaskListManager, projectManager: ProjectManager, listItemManager: ListItemManager) {
        self.taskListManager = taskListManager
        self.projectManager = projectManager
        self.listItemManager = listItemManager
    }

    /// Fetches all lists and projects from SwiftData and expands every list card by default.
    func loadData() {
        allLists = taskListManager.fetchAllLists()
        allProjects = projectManager.fetchProjects()
        for list in allLists {
            expandedListIDs.insert(list.id)
        }
    }

    /// Toggles whether a list card is expanded or collapsed on the home screen.
    func toggleExpansion(for list: TaskList) {
        if expandedListIDs.contains(list.id) {
            expandedListIDs.remove(list.id)
        } else {
            expandedListIDs.insert(list.id)
        }
    }

    /// Returns `true` if the given list's card is currently expanded.
    func isExpanded(_ list: TaskList) -> Bool {
        expandedListIDs.contains(list.id)
    }

    /// Resets the filter to show all lists and projects.
    func selectAll() {
        selectedProject = nil
        selectedList = nil
        filterLabel = "All"
    }

    /// Filters the home screen to show only lists belonging to the given project.
    func selectProject(_ project: Project) {
        selectedProject = project
        selectedList = nil
        filterLabel = project.name
    }

    /// Filters the home screen to show only the given list (inline detail mode).
    func selectList(_ list: TaskList) {
        selectedProject = nil
        selectedList = list
        filterLabel = list.name
    }

    /// Deletes all completed items from every currently visible list.
    func clearCompleted() {
        for list in filteredLists {
            let completed = (list.items ?? []).filter(\.isCompleted)
            for item in completed {
                listItemManager.deleteItem(item)
            }
        }
    }
}
