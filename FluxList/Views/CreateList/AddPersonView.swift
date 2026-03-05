import SwiftUI

/// A navigation destination that lets the user search for and add people to a shared list.
///
/// Shows the current user's friends by default. The search bar performs an exact-email
/// lookup against Firestore to find other registered users. Selecting a person appends
/// their `stableID` to the bound ``sharedUserIDs`` array.
struct AddPersonView: View {
    @Environment(UserManager.self) private var userManager
    @Environment(FirebaseSyncManager.self) private var firebaseSyncManager
    @Environment(\.dismiss) private var dismiss

    /// Binding to the list of user IDs the list will be shared with (owned by ``CreateListViewModel``).
    @Binding var sharedUserIDs: [String]

    /// Created lazily on `.task` so environment objects are available.
    @State private var viewModel: AddPersonViewModel?

    var body: some View {
        Group {
            if let viewModel {
                AddPersonContentView(
                    viewModel: viewModel,
                    sharedUserIDs: $sharedUserIDs
                )
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Add Person")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                let vm = AddPersonViewModel(
                    userManager: userManager,
                    firebaseSyncManager: firebaseSyncManager,
                    alreadyAddedIDs: sharedUserIDs
                )
                viewModel = vm
                await vm.loadFriends()
            }
        }
    }
}

// MARK: - Content

private struct AddPersonContentView: View {
    @Bindable var viewModel: AddPersonViewModel
    @Binding var sharedUserIDs: [String]

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Search by email", text: $viewModel.searchText)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button("Search", systemImage: "magnifyingglass") {
                        Task { await viewModel.searchByEmail() }
                    }
                    .labelStyle(.iconOnly)
                    .disabled(viewModel.searchText.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty)
                }
            }

            Section {
                if viewModel.isSearching {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }

                ForEach(viewModel.displayedPeople) { person in
                    AddPersonRow(
                        person: person,
                        isAdded: viewModel.isAlreadyAdded(person.id),
                        onAdd: {
                            sharedUserIDs.append(person.id)
                            viewModel.markAsAdded(person.id)
                        }
                    )
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } header: {
                if !viewModel.searchResults.isEmpty {
                    Text("Search Results & Friends")
                } else {
                    Text("Friends")
                }
            }
        }
    }
}
