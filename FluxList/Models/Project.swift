import Foundation
import SwiftData

/// A named group of ``TaskList`` items, used to organize lists by category
/// (e.g. "Work", "Personal", "Vacation").
///
/// Deleting a project does **not** cascade-delete its lists; they become unassigned instead.
@Model
final class Project: Identifiable {
    var id: UUID = UUID()
    var name: String = ""

    /// All task lists assigned to this project. Maintained automatically via the inverse on ``TaskList/project``.
    @Relationship(inverse: \TaskList.project)
    var lists: [TaskList]?

    init(name: String) {
        self.id = UUID()
        self.name = name
    }
}
