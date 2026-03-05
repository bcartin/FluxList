import Foundation

/// Drives the "All Lists" overview screen accessible from the user menu.
///
/// Shows only lists created by the current user (filtered by ``TaskList/createdBy``),
/// and supports searching, deleting, and launching the edit sheet.
@MainActor @Observable
final class ListsOverviewViewModel {
    private let taskListManager: TaskListManager
    /// The `stableID` of the current user, used to filter lists to only those they created.
    private let currentUserID: String

    /// All lists created by the current user.
    var lists: [TaskList] = []
    /// Search bar text for filtering by list name.
    var searchText: String = ""

    /// Lists filtered by the search query (case-insensitive, locale-aware).
    var filteredLists: [TaskList] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return lists }
        return lists.filter { $0.name.localizedStandardContains(query) }
    }

    /// The list currently being edited in the ``CreateListSheet``, or `nil`.
    var editingList: TaskList?

    init(taskListManager: TaskListManager, currentUserID: String) {
        self.taskListManager = taskListManager
        self.currentUserID = currentUserID
    }

    /// Reloads lists from SwiftData, filtering to only those created by this user.
    func loadLists() {
        lists = taskListManager.fetchAllLists().filter { $0.createdBy == currentUserID }
    }

    /// Deletes a list and refreshes the displayed data.
    func deleteList(_ list: TaskList) {
        taskListManager.deleteList(list)
        loadLists()
    }

    /// Sets the list that should be opened in the edit sheet.
    func beginEditing(_ list: TaskList) {
        editingList = list
    }

    /// Returns the total number of items in the given list.
    func itemCount(for list: TaskList) -> Int {
        list.items?.count ?? 0
    }

    /// Returns how many items in the given list are marked as completed.
    func completedCount(for list: TaskList) -> Int {
        list.items?.filter(\.isCompleted).count ?? 0
    }
}
