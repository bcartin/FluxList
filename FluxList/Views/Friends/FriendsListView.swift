import SwiftUI

/// A modal sheet listing the current user's friends with search and swipe-to-delete.
///
/// Friends are resolved from Firestore on first appearance. The list also shows
/// an empty state if no friends have been added yet.
struct FriendsListView: View {
    @Environment(UserManager.self) private var userManager
    @Environment(FirebaseSyncManager.self) private var firebaseSyncManager
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: FriendsListViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    FriendsListContentView(viewModel: viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Text("Done")
                            .bold()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppTheme.brandGradient, in: .capsule)
                            .fixedSize()
                    }
                    .buttonStyle(.borderless)
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .task {
                if viewModel == nil {
                    let vm = FriendsListViewModel(
                        userManager: userManager,
                        firebaseSyncManager: firebaseSyncManager
                    )
                    viewModel = vm
                    await vm.loadFriends()
                }
            }
        }
    }
}

// MARK: - Content

/// The searchable list body, extracted so the outer view can manage the loading state.
private struct FriendsListContentView: View {
    @Bindable var viewModel: FriendsListViewModel

    var body: some View {
        List {
            ForEach(viewModel.filteredFriends) { friend in
                FriendRow(friend: friend)
            }
            .onDelete { offsets in
                viewModel.deleteFriends(at: offsets)
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search friends")
        .overlay {
            if !viewModel.isLoading && viewModel.friends.isEmpty {
                ContentUnavailableView(
                    "No Friends Yet",
                    systemImage: "person.2",
                    description: Text("Friends you add to shared lists will appear here.")
                )
            } else if !viewModel.isLoading && viewModel.filteredFriends.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            }
        }
    }
}

// MARK: - Row

/// A single row displaying a friend's avatar, name, and email.
private struct FriendRow: View {
    let friend: FriendsListViewModel.FriendInfo

    var body: some View {
        HStack {
            UserAvatarView(name: friend.name, size: 32)

            VStack(alignment: .leading) {
                Text(friend.name)
                    .font(.subheadline)
                    .bold()
                if !friend.email.isEmpty {
                    Text(friend.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
