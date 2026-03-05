import Foundation
import SwiftData

/// A single to-do item that belongs to a ``TaskList``.
///
/// Each item tracks its completion state, who created it, and which list it belongs to.
/// Items are cascade-deleted when their parent ``TaskList`` is removed.
@Model
final class ListItem: Identifiable {
    var id: UUID = UUID()
    /// The user-visible title of the item (e.g. "Buy milk").
    var name: String = ""
    /// Whether the user has marked this item as done.
    var isCompleted: Bool = false
    var createdAt: Date = Date.now
    /// The `stableID` of the user who created this item, used to attribute authorship in shared lists.
    var createdBy: String = ""

    /// The parent list this item belongs to. Nil only during transient creation states.
    var taskList: TaskList?

    init(name: String, isCompleted: Bool = false, createdBy: String = "", taskList: TaskList? = nil) {
        self.id = UUID()
        self.name = name
        self.isCompleted = isCompleted
        self.createdBy = createdBy
        self.taskList = taskList
    }
}
