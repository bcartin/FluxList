import Foundation
import OSLog
import SwiftData

private let logger = Logger(subsystem: "com.fluxlist", category: "TaskListManager")

/// CRUD manager for ``TaskList`` records.
///
/// Provides methods to create, fetch, update, and delete task lists, as well as
/// manage which users have access to a shared list. All mutations persist to
/// SwiftData first and then sync to Firestore in the background.
@MainActor @Observable
final class TaskListManager {
    private let modelContext: ModelContext
    private var syncManager: FirebaseSyncManager?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Call once after FirebaseSyncManager is available to enable sync.
    func setSyncManager(_ syncManager: FirebaseSyncManager) {
        self.syncManager = syncManager
    }

    /// Persists any pending changes in the model context to disk.
    private func save() {
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save context: \(error.localizedDescription)")
        }
    }

    /// Kicks off a background Firestore sync for the given list.
    private func syncList(_ list: TaskList) {
        guard let syncManager else { return }
        Task {
            do {
                try await syncManager.syncList(list)
            } catch {
                logger.error("Failed to sync list '\(list.name)': \(error.localizedDescription)")
            }
        }
    }

    /// Returns every task list in the store, sorted oldest-first by creation date.
    func fetchAllLists() -> [TaskList] {
        let descriptor = FetchDescriptor<TaskList>(sortBy: [SortDescriptor(\.createdAt)])
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch all lists: \(error.localizedDescription)")
            return []
        }
    }

    /// Returns only the lists that the given user has access to (i.e. their `stableID`
    /// appears in the list's ``TaskList/userIDs`` array).
    func fetchLists(for userID: String) -> [TaskList] {
        let allLists = fetchAllLists()
        return allLists.filter { $0.userIDs.contains(userID) }
    }

    /// Returns all lists assigned to the given project, sorted by creation date.
    func fetchLists(for project: Project) -> [TaskList] {
        let projectID = project.persistentModelID
        let descriptor = FetchDescriptor<TaskList>(
            predicate: #Predicate { $0.project?.persistentModelID == projectID },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch lists for project '\(project.name)': \(error.localizedDescription)")
            return []
        }
    }

    /// Creates a new task list with the given properties, saves it, and syncs to Firestore.
    @discardableResult
    func createList(
        name: String,
        colorName: String = "blue",
        iconName: String = "list.bullet",
        project: Project? = nil,
        createdBy: String = "",
        userIDs: [String] = []
    ) -> TaskList {
        let list = TaskList(
            name: name,
            colorName: colorName,
            iconName: iconName,
            project: project,
            createdBy: createdBy
        )
        list.userIDs = userIDs
        modelContext.insert(list)
        save()
        syncList(list)
        return list
    }

    /// Deletes a list and all its items locally, then removes it from Firestore.
    func deleteList(_ list: TaskList) {
        let listID = list.id
        modelContext.delete(list)
        save()
        guard let syncManager else { return }
        Task {
            do {
                try await syncManager.deleteList(listID)
            } catch {
                logger.error("Failed to delete list from Firestore: \(error.localizedDescription)")
            }
        }
    }

    /// Selectively updates one or more list properties and syncs the result.
    /// Pass `nil` for any parameter you don't want to change.
    func updateList(
        _ list: TaskList,
        name: String? = nil,
        colorName: String? = nil,
        iconName: String? = nil,
        project: Project? = nil
    ) {
        if let name { list.name = name }
        if let colorName { list.colorName = colorName }
        if let iconName { list.iconName = iconName }
        if let project { list.project = project }
        save()
        syncList(list)
    }

    /// Grants a user access to a list by appending their `stableID` to ``TaskList/userIDs``.
    func addUserID(_ userID: String, to list: TaskList) {
        guard !list.userIDs.contains(userID) else { return }
        list.userIDs.append(userID)
        save()
        syncList(list)
    }

    /// Revokes a user's access to a list by removing their `stableID` from ``TaskList/userIDs``.
    func removeUserID(_ userID: String, from list: TaskList) {
        list.userIDs.removeAll { $0 == userID }
        save()
        syncList(list)
    }
}
