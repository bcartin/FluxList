import Foundation
import OSLog
import SwiftData

private let logger = Logger(subsystem: "com.fluxlist", category: "ListItemManager")

/// CRUD manager for ``ListItem`` records.
///
/// Operates on a SwiftData `ModelContext` and optionally syncs changes to
/// Firestore via ``FirebaseSyncManager``. Every mutating method persists locally
/// first, then fires a background sync if a sync manager is configured.
///
/// Also integrates with ``UserManager`` to track item-name frequency so
/// frequently-added items can be auto-promoted to favorite suggestions for Pro users.
@MainActor @Observable
final class ListItemManager {
    private let modelContext: ModelContext
    /// Set via ``setSyncManager(_:)`` once the sync layer is ready.
    private var syncManager: FirebaseSyncManager?
    private var userManager: UserManager?
    private var storeKitManager: StoreKitManager?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Call once after FirebaseSyncManager is available to enable sync.
    func setSyncManager(_ syncManager: FirebaseSyncManager) {
        self.syncManager = syncManager
    }

    /// Call once after UserManager and StoreKitManager are available to enable frequency tracking.
    func setFrequencyTracking(userManager: UserManager, storeKitManager: StoreKitManager) {
        self.userManager = userManager
        self.storeKitManager = storeKitManager
    }

    /// Persists any pending changes in the model context to disk.
    private func save() {
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save context: \(error.localizedDescription)")
        }
    }

    /// Kicks off a background Firestore sync for the given list (if sync is configured).
    private func syncList(_ list: TaskList?) {
        guard let list, let syncManager else { return }
        Task {
            do {
                try await syncManager.syncList(list)
            } catch {
                logger.error("Failed to sync list '\(list.name)': \(error.localizedDescription)")
            }
        }
    }

    /// Returns all items in the given list, sorted oldest-first by creation date.
    func fetchItems(for list: TaskList) -> [ListItem] {
        list.items?.sorted(by: { $0.createdAt < $1.createdAt }) ?? []
    }

    /// Creates a new item, inserts it into the list, saves locally, syncs remotely,
    /// and records item-name frequency for Pro users.
    @discardableResult
    func createItem(name: String, createdBy: String = "", in list: TaskList) -> ListItem {
        let item = ListItem(name: name, createdBy: createdBy, taskList: list)
        modelContext.insert(item)
        if var items = list.items {
            items.append(item)
            list.items = items
        } else {
            list.items = [item]
        }
        save()
        syncList(list)

        // Track item frequency for pro users so common items become suggestions.
        if storeKitManager?.isProUser == true {
            userManager?.recordItemFrequency(name)
        }

        return item
    }

    /// Flips the completion state of an item and persists + syncs the change.
    func toggleCompletion(_ item: ListItem) {
        item.isCompleted.toggle()
        save()
        syncList(item.taskList)
    }

    /// Removes an item from SwiftData and deletes it from Firestore if sync is configured.
    func deleteItem(_ item: ListItem) {
        let itemID = item.id
        let listID = item.taskList?.id
        modelContext.delete(item)
        save()
        guard let listID, let syncManager else { return }
        Task {
            do {
                try await syncManager.deleteItem(itemID, fromList: listID)
            } catch {
                logger.error("Failed to delete item from Firestore: \(error.localizedDescription)")
            }
        }
    }

    /// Renames an item and persists + syncs the change.
    func updateItem(_ item: ListItem, name: String) {
        item.name = name
        save()
        syncList(item.taskList)
    }
}
