import Foundation
import OSLog
import SwiftData

private let logger = Logger(subsystem: "com.fluxlist", category: "ProjectManager")

/// CRUD manager for ``Project`` records.
///
/// Projects are organizational containers that group related ``TaskList`` items together.
/// Like the other managers, changes are saved locally first and then synced to Firestore
/// in the background when a ``FirebaseSyncManager`` is configured.
@MainActor @Observable
final class ProjectManager {
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

    /// Kicks off a background Firestore sync for the given project.
    private func syncProject(_ project: Project) {
        guard let syncManager else { return }
        Task {
            do {
                try await syncManager.syncProject(project)
            } catch {
                logger.error("Failed to sync project '\(project.name)': \(error.localizedDescription)")
            }
        }
    }

    /// Returns all projects sorted alphabetically by name.
    func fetchProjects() -> [Project] {
        let descriptor = FetchDescriptor<Project>(sortBy: [SortDescriptor(\.name)])
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch projects: \(error.localizedDescription)")
            return []
        }
    }

    /// Creates a new project, inserts it into SwiftData, and syncs to Firestore.
    @discardableResult
    func createProject(name: String) -> Project {
        let project = Project(name: name)
        modelContext.insert(project)
        save()
        syncProject(project)
        return project
    }

    /// Removes a project from SwiftData and deletes it from Firestore.
    /// Associated lists are **not** deleted — they become unassigned.
    func deleteProject(_ project: Project) {
        let projectID = project.id
        modelContext.delete(project)
        save()
        guard let syncManager else { return }
        Task {
            do {
                try await syncManager.deleteProject(projectID)
            } catch {
                logger.error("Failed to delete project from Firestore: \(error.localizedDescription)")
            }
        }
    }

    /// Renames a project and persists + syncs the change.
    func updateProject(_ project: Project, name: String) {
        project.name = name
        save()
        syncProject(project)
    }
}
