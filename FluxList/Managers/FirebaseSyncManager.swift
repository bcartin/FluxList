import Foundation
import SwiftData
import FirebaseAuth
import FirebaseFirestore

/// Handles two-way synchronization between the local SwiftData store and Cloud Firestore.
///
/// Sync is gated behind two requirements (see ``canSync``):
/// 1. The user must be a Pro subscriber (via ``StoreKitManager``).
/// 2. The user must be signed in to Firebase (via ``AuthManager``).
///
/// ## Firestore data model
/// - `users/{uid}` — user profile data (name, email, favorites, friends, etc.)
/// - `users/{uid}/projects/{projectID}` — projects owned by the user.
/// - `lists/{listID}` — shared task lists with a `userIDs` array for access control.
/// - `lists/{listID}/items/{itemID}` — individual to-do items within a list.
@MainActor @Observable
final class FirebaseSyncManager {
    private var db: Firestore { Firestore.firestore() }
    private let authManager: AuthManager
    private let storeKitManager: StoreKitManager

    /// `true` while a sync operation is in flight; can be used to show a loading indicator.
    private(set) var isSyncing = false

    /// Whether sync is allowed — requires both Pro subscription and Firebase sign-in.
    var canSync: Bool {
        storeKitManager.isProUser && authManager.isSignedIn
    }

    init(authManager: AuthManager, storeKitManager: StoreKitManager) {
        self.authManager = authManager
        self.storeKitManager = storeKitManager
    }

    // MARK: - User Sync

    /// Syncs the local user profile to Firestore at `users/{firebaseUID}`.
    func syncUser(_ user: User) async throws {
        guard canSync, let uid = authManager.firebaseUser?.uid else { return }
        isSyncing = true
        defer { isSyncing = false }

        let userRef = db.collection("users").document(uid)

        let userData: [String: Any] = [
            "name": user.name,
            "email": user.email,
            "firebaseUID": uid,
            "favoriteListIDs": user.favoriteListIDs,
            "favoriteSuggestions": user.favoriteSuggestions,
            "itemFrequencies": user.getItemFrequencies(),
            "friends": user.friends,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await userRef.setData(userData, merge: true)
    }

    /// Fetches the current user's profile from Firestore and applies it to the local User model.
    func fetchUserProfile(for user: User) async throws {
        guard canSync, let uid = authManager.firebaseUser?.uid else { return }

        let snapshot = try await db.collection("users").document(uid).getDocument()

        guard let data = snapshot.data() else { return }

        if let name = data["name"] as? String {
            user.name = name
        }
        if let email = data["email"] as? String {
            user.email = email
        }
        if let favoriteListIDs = data["favoriteListIDs"] as? [String] {
            user.favoriteListIDs = favoriteListIDs
        }
        if let favoriteSuggestions = data["favoriteSuggestions"] as? [String] {
            user.favoriteSuggestions = favoriteSuggestions
        }
        if let itemFrequencies = data["itemFrequencies"] as? [String: Int] {
            user.setItemFrequencies(itemFrequencies)
        }
        if let friends = data["friends"] as? [String] {
            user.friends = friends
        }

        user.firebaseUID = uid
    }

    // MARK: - User Lookup

    /// A lightweight representation of a remote user fetched from Firestore.
    struct RemoteUser: Sendable {
        let uid: String
        let name: String
        let email: String
    }

    /// Fetches a user from Firestore by their Firebase UID.
    func fetchUser(byID uid: String) async throws -> RemoteUser? {
        guard canSync else { return nil }

        let snapshot = try await db.collection("users").document(uid).getDocument()
        guard let data = snapshot.data() else { return nil }

        return RemoteUser(
            uid: uid,
            name: data["name"] as? String ?? "",
            email: data["email"] as? String ?? ""
        )
    }

    /// Fetches a user from Firestore by their email address.
    func fetchUser(byEmail email: String) async throws -> RemoteUser? {
        guard canSync else { return nil }

        let snapshot = try await db.collection("users")
            .whereField("email", isEqualTo: email)
            .limit(to: 1)
            .getDocuments()

        guard let document = snapshot.documents.first else { return nil }
        let data = document.data()

        return RemoteUser(
            uid: document.documentID,
            name: data["name"] as? String ?? "",
            email: data["email"] as? String ?? ""
        )
    }

    // MARK: - List Sync

    /// Syncs a list to Firestore as a top-level document.
    /// Lists are stored at `lists/{listID}` and contain a `userIDs` array
    /// to determine which users have access.
    func syncList(_ list: TaskList) async throws {
        guard canSync else { return }
        isSyncing = true
        defer { isSyncing = false }

        let listRef = db.collection("lists").document(list.id.uuidString)

        let listData: [String: Any] = [
            "id": list.id.uuidString,
            "name": list.name,
            "colorName": list.colorName,
            "iconName": list.iconName,
            "createdAt": Timestamp(date: list.createdAt),
            "createdBy": list.createdBy,
            "userIDs": list.userIDs,
            "projectName": list.project?.name ?? "",
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await listRef.setData(listData, merge: true)

        // Sync items as a subcollection of the list
        for item in list.items ?? [] {
            let itemRef = listRef.collection("items").document(item.id.uuidString)
            let itemData: [String: Any] = [
                "id": item.id.uuidString,
                "name": item.name,
                "isCompleted": item.isCompleted,
                "createdBy": item.createdBy,
                "createdAt": Timestamp(date: item.createdAt)
            ]
            try await itemRef.setData(itemData, merge: true)
        }
    }

    /// Convenience to sync every list in the given array sequentially.
    func syncAllLists(_ lists: [TaskList]) async throws {
        guard canSync else { return }
        for list in lists {
            try await syncList(list)
        }
    }

    /// Deletes a single item from a list's items subcollection in Firestore.
    func deleteItem(_ itemID: UUID, fromList listID: UUID) async throws {
        guard canSync else { return }
        try await db.collection("lists")
            .document(listID.uuidString)
            .collection("items")
            .document(itemID.uuidString)
            .delete()
    }

    /// Deletes a list document and all its items subcollection from Firestore.
    func deleteList(_ listID: UUID) async throws {
        guard canSync else { return }
        let listRef = db.collection("lists").document(listID.uuidString)

        // Delete all items in the subcollection first
        let itemsSnapshot = try await listRef.collection("items").getDocuments()
        for document in itemsSnapshot.documents {
            try await document.reference.delete()
        }

        // Delete the list document itself
        try await listRef.delete()
    }

    // MARK: - Project Sync

    /// Syncs a project to Firestore at `users/{uid}/projects/{projectID}`.
    func syncProject(_ project: Project) async throws {
        guard canSync, let uid = authManager.firebaseUser?.uid else { return }

        let projectRef = db.collection("users").document(uid)
            .collection("projects").document(project.id.uuidString)

        let projectData: [String: Any] = [
            "id": project.id.uuidString,
            "name": project.name,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await projectRef.setData(projectData, merge: true)
    }

    /// Deletes a project document from Firestore.
    func deleteProject(_ projectID: UUID) async throws {
        guard canSync, let uid = authManager.firebaseUser?.uid else { return }

        try await db.collection("users").document(uid)
            .collection("projects").document(projectID.uuidString)
            .delete()
    }

    // MARK: - Fetch & Merge Lists

    /// Fetches all lists where the current user's Firebase UID is in the `userIDs` array,
    /// then merges them into the local SwiftData store. New lists are inserted, existing
    /// lists are updated, and items are synced within each list.
    func fetchAndMergeRemoteLists(into context: ModelContext) async throws {
        guard canSync, let uid = authManager.firebaseUser?.uid else { return }
        isSyncing = true
        defer { isSyncing = false }

        let snapshot = try await db.collection("lists")
            .whereField("userIDs", arrayContains: uid)
            .getDocuments()

        // Fetch all existing local lists once for efficient lookup
        let allLocalLists = (try? context.fetch(FetchDescriptor<TaskList>())) ?? []
        let localListsByID = Dictionary(uniqueKeysWithValues: allLocalLists.compactMap { list in
            (list.id.uuidString, list)
        })

        for document in snapshot.documents {
            let data = document.data()

            guard let idString = data["id"] as? String,
                  let listUUID = UUID(uuidString: idString) else { continue }

            let name = data["name"] as? String ?? ""
            let colorName = data["colorName"] as? String ?? "blue"
            let iconName = data["iconName"] as? String ?? "list.bullet"
            let createdBy = data["createdBy"] as? String ?? ""
            let userIDs = data["userIDs"] as? [String] ?? []
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date.now

            if let existingList = localListsByID[idString] {
                // Update existing local list with remote data
                existingList.name = name
                existingList.colorName = colorName
                existingList.iconName = iconName
                existingList.createdBy = createdBy
                existingList.userIDs = userIDs
            } else {
                // Insert new list from remote
                let newList = TaskList(
                    name: name,
                    colorName: colorName,
                    iconName: iconName,
                    createdBy: createdBy
                )
                // Set the UUID to match the remote ID so future syncs can find it
                newList.id = listUUID
                newList.createdAt = createdAt
                newList.userIDs = userIDs
                context.insert(newList)
            }

            // Merge items for this list
            try await mergeRemoteItems(for: idString, listUUID: listUUID, into: context)
        }

        try context.save()
    }

    /// Fetches items from a remote list's subcollection and merges them into the local list.
    private func mergeRemoteItems(for listIDString: String, listUUID: UUID, into context: ModelContext) async throws {
        let itemsSnapshot = try await db.collection("lists")
            .document(listIDString)
            .collection("items")
            .getDocuments()

        // Find the local list
        let descriptor = FetchDescriptor<TaskList>(
            predicate: #Predicate { $0.id == listUUID }
        )
        guard let localList = (try? context.fetch(descriptor))?.first else { return }

        let existingItemIDs = Set((localList.items ?? []).map { $0.id.uuidString })

        for itemDoc in itemsSnapshot.documents {
            let itemData = itemDoc.data()
            guard let itemIDString = itemData["id"] as? String,
                  let itemUUID = UUID(uuidString: itemIDString) else { continue }

            let itemName = itemData["name"] as? String ?? ""
            let isCompleted = itemData["isCompleted"] as? Bool ?? false
            let itemCreatedBy = itemData["createdBy"] as? String ?? ""
            let itemCreatedAt = (itemData["createdAt"] as? Timestamp)?.dateValue() ?? Date.now

            if existingItemIDs.contains(itemIDString) {
                // Update existing item
                if let existingItem = localList.items?.first(where: { $0.id.uuidString == itemIDString }) {
                    existingItem.name = itemName
                    existingItem.isCompleted = isCompleted
                    existingItem.createdBy = itemCreatedBy
                }
            } else {
                // Insert new item
                let newItem = ListItem(
                    name: itemName,
                    isCompleted: isCompleted,
                    createdBy: itemCreatedBy,
                    taskList: localList
                )
                newItem.id = itemUUID
                newItem.createdAt = itemCreatedAt
                context.insert(newItem)
            }
        }
    }
}
