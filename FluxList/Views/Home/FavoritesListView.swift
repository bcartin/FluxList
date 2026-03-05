import SwiftUI
import SwiftData

/// A modal sheet for managing the user's favorite item suggestions.
///
/// Users can add new suggestions manually, delete existing ones via swipe,
/// and search the list. The suggestions appear as quick-add chips in the
/// add-item bar throughout the app.
struct FavoritesListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UserManager.self) private var userManager

    @State private var viewModel: FavoritesListViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    FavoritesContentView(viewModel: viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Favorites")
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
                ToolbarItem(placement: .topBarTrailing) {
                    if let viewModel {
                        Button(action: { viewModel.beginCreating() }) {
                            Label("New Favorite", systemImage: "plus")
                                .bold()
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(AppTheme.brandGradient, in: .circle)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .task {
                if viewModel == nil {
                    let vm = FavoritesListViewModel(userManager: userManager)
                    vm.loadFavorites()
                    viewModel = vm
                }
            }
        }
    }
}

// MARK: - Content

private struct FavoritesContentView: View {
    @Bindable var viewModel: FavoritesListViewModel

    var body: some View {
        List {
            ForEach(viewModel.filteredFavorites.enumerated(), id: \.element) { index, favorite in
                FavoriteRow(name: favorite)
            }
            .onDelete { indexSet in
                // Map filtered indices back to the source array
                let filtered = viewModel.filteredFavorites
                for index in indexSet {
                    if let sourceIndex = viewModel.favorites.firstIndex(of: filtered[index]) {
                        viewModel.deleteFavorite(at: sourceIndex)
                    }
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search favorites")
        .overlay {
            if viewModel.favorites.isEmpty {
                ContentUnavailableView(
                    "No Favorites",
                    systemImage: "star",
                    description: Text("Add your frequently used tasks for quick access.")
                )
            } else if viewModel.filteredFavorites.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            }
        }
        .alert("New Favorite", isPresented: $viewModel.isShowingCreateAlert) {
            TextField("Task name", text: $viewModel.newFavoriteName)
            Button("Add") {
                viewModel.confirmCreate()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a task name to add to your favorites.")
        }
    }
}

// MARK: - Row

private struct FavoriteRow: View {
    let name: String

    var body: some View {
        HStack {
            Image(systemName: "star.fill")
                .foregroundStyle(AppTheme.gradientMid)

            Text(name)
        }
    }
}

// MARK: - Preview

#Preview {
    let schema = Schema([User.self, Project.self, TaskList.self, ListItem.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    let context = container.mainContext

    SampleData.populateSampleData(in: context)

    return FavoritesListView()
        .modelContainer(container)
        .environment({
            let um = UserManager(modelContext: context)
            um.fetchOrCreateCurrentUser()
            return um
        }())
}
