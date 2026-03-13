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
    /// Tracks pending sync tasks per project ID so rapid mutations coalesce into one sync.
    private var pendingSyncTasks: [UUID: Task<Void, Never>] = [:]

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

    /// Debounces Firestore syncs for the given project.
    ///
    /// Cancels any previously pending sync for the same project and schedules a new one
    /// after a short delay, preventing rapid mutations from spawning concurrent requests.
    private func syncProject(_ project: Project) {
        guard let syncManager else { return }
        let projectID = project.id
        pendingSyncTasks[projectID]?.cancel()
        pendingSyncTasks[projectID] = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            do {
                try await syncManager.syncProject(project)
            } catch {
                logger.error("Failed to sync project '\(project.name)': \(error.localizedDescription)")
            }
            pendingSyncTasks[projectID] = nil
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
