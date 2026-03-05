import SwiftUI

/// An expandable card representing a single ``TaskList`` on the home screen.
///
/// When collapsed, only the header (icon, name, shared user avatars) is visible.
/// When expanded, the card also shows each ``ListItemRow`` with checkboxes.
/// Tapping the "+" navigates to the full list detail view.
struct ListCardView: View {
    /// The task list to display.
    let list: TaskList
    /// Whether the card is expanded to show its items.
    let isExpanded: Bool
    /// Called when the expand/collapse chevron is tapped.
    let onToggleExpansion: () -> Void
    /// Called when a checkbox is tapped to toggle an item's completion.
    let onToggleItem: (ListItem) -> Void
    /// Called when the "+" button is tapped to navigate to the list detail.
    let onAddItem: () -> Void

    /// Resolved SwiftUI color from the list's stored color name.
    private var listColor: Color {
        AppColor(rawValue: list.colorName)?.color ?? .blue
    }

    /// Items sorted by creation date for consistent display order.
    private var sortedItems: [ListItem] {
        (list.items ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            CardHeaderView(
                list: list,
                listColor: listColor,
                isExpanded: isExpanded,
                onToggleExpansion: onToggleExpansion,
                onAddItem: onAddItem
            )

            // Items (when expanded)
            if isExpanded && !sortedItems.isEmpty {
                VStack(alignment: .leading) {
                    ForEach(sortedItems) { item in
                        ListItemRow(item: item) {
                            onToggleItem(item)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(listColor.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(listColor.opacity(0.15), lineWidth: 1)
        )
        .clipShape(.rect(cornerRadius: 12))
    }
}

// MARK: - Card Header

/// The header row of a list card: icon, name, expand chevron, shared-user avatars, and add button.
private struct CardHeaderView: View {
    @Environment(StoreKitManager.self) private var storeKitManager

    let list: TaskList
    let listColor: Color
    let isExpanded: Bool
    let onToggleExpansion: () -> Void
    let onAddItem: () -> Void

    var body: some View {
        HStack {
            Image(systemName: list.iconName)
                .foregroundStyle(listColor)

            Text(list.name)
                .bold()

            Button("Toggle", systemImage: isExpanded ? "chevron.down" : "chevron.right", action: onToggleExpansion)
                .labelStyle(.iconOnly)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            // Shared user ID avatars (pro only)
            if storeKitManager.isProUser {
                SharedUsersRow(userIDs: list.userIDs)
            }

            Button("Add item", systemImage: "plus.circle", action: onAddItem)
                .labelStyle(.iconOnly)
                .font(.title2)
                .foregroundStyle(AppTheme.gradientMid)
        }
        .padding()
    }
}

// MARK: - Shared Users Row

/// Displays overlapping avatar circles for users sharing this list (excluding the current user).
/// Shows up to 3 avatars. Resolves display names from the cache or Firestore.
private struct SharedUsersRow: View {
    let userIDs: [String]
    @Environment(UserManager.self) private var userManager

    /// All shared user IDs except the current user's.
    private var otherUserIDs: [String] {
        let currentID = userManager.currentUser?.stableID
        return userIDs.filter { $0 != currentID }
    }

    var body: some View {
        if !otherUserIDs.isEmpty {
            let _ = resolveIfNeeded()

            HStack(spacing: -8) {
                ForEach(otherUserIDs.prefix(3), id: \.self) { userID in
                    UserAvatarView(
                        name: userManager.userNameCache[userID] ?? "?",
                        size: 24
                    )
                }
            }
        }
    }

    /// Triggers name resolution during body evaluation so local names
    /// are available immediately. Firebase lookups happen asynchronously
    /// and will trigger a re-render via @Observable when they complete.
    private func resolveIfNeeded() {
        let needsResolve = otherUserIDs.contains { userManager.userNameCache[$0] == nil }
        if needsResolve {
            userManager.resolveUserNames(for: otherUserIDs)
        }
    }
}
