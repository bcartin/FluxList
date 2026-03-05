import Foundation
import SwiftData

/// Drives a single list's detail view, providing sorted items, add/delete/toggle
/// operations, and the text field state for adding new items.
///
/// Used by both the full-screen ``ListDetailView`` and the inline
/// ``SingleListContentView`` on the home screen.
@MainActor @Observable
final class ListViewModel {
    /// The task list this view model manages.
    let taskList: TaskList
    /// Bound to the add-item text field at the bottom of the list.
    var newItemName: String = ""

    private let listItemManager: ListItemManager

    /// Items sorted so incomplete items appear first (oldest first),
    /// followed by completed items (oldest first).
    var sortedItems: [ListItem] {
        (taskList.items ?? []).sorted { a, b in
            if a.isCompleted != b.isCompleted {
                return !a.isCompleted
            }
            return a.createdAt < b.createdAt
        }
    }

    /// Whether the add-item text field contains a valid (non-blank) name.
    var canAddItem: Bool {
        !newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(taskList: TaskList, listItemManager: ListItemManager) {
        self.taskList = taskList
        self.listItemManager = listItemManager
    }

    /// Creates a new item from the current ``newItemName``, then clears the field.
    func addItem(createdBy: String) {
        guard canAddItem else { return }
        listItemManager.createItem(
            name: newItemName.trimmingCharacters(in: .whitespacesAndNewlines),
            createdBy: createdBy,
            in: taskList
        )
        newItemName = ""
    }

    /// Toggles the completion state of the given item.
    func toggleCompletion(_ item: ListItem) {
        listItemManager.toggleCompletion(item)
    }

    /// Permanently deletes a single item.
    func deleteItem(_ item: ListItem) {
        listItemManager.deleteItem(item)
    }

    /// Deletes all completed items in this list.
    func deleteCompletedItems() {
        let completed = (taskList.items ?? []).filter(\.isCompleted)
        for item in completed {
            listItemManager.deleteItem(item)
        }
    }
}
