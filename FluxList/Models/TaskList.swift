import Foundation
import SwiftData

/// A named list of ``ListItem`` to-dos (e.g. "Groceries", "Sprint 12 Tasks").
///
/// Lists can optionally belong to a ``Project`` and can be shared with other users
/// via the ``userIDs`` array. Each list has a customizable color and SF Symbol icon
/// so it stands out visually on the home screen.
///
/// Deleting a `TaskList` cascade-deletes all of its child ``ListItem`` entries.
@Model
final class TaskList: Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    /// A color identifier (e.g. "blue", "red") used to tint the list's card and icon in the UI.
    var colorName: String = "blue"
    /// An SF Symbol name (e.g. "list.bullet", "cart") displayed alongside the list title.
    var iconName: String = "list.bullet"
    var createdAt: Date = Date.now
    /// The `stableID` of the user who originally created this list.
    var createdBy: String = ""

    /// `stableID` values of every user who can view and edit this list.
    /// Used to implement list sharing — when a user is added, their `stableID` is appended here.
    var userIDs: [String] = []

    /// The optional project this list is organized under.
    var project: Project?

    /// All to-do items in this list. Cascade-deleted when the list itself is removed.
    @Relationship(deleteRule: .cascade, inverse: \ListItem.taskList)
    var items: [ListItem]?

    init(
        name: String,
        colorName: String = "blue",
        iconName: String = "list.bullet",
        project: Project? = nil,
        createdBy: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.colorName = colorName
        self.iconName = iconName
        self.project = project
        self.createdBy = createdBy
    }
}
