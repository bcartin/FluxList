import SwiftUI
import SwiftData

/// A modal sheet showing all lists the current user created, with search,
/// swipe-to-delete, and the ability to tap into an edit sheet for any list.
struct ListsOverviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TaskListManager.self) private var taskListManager
    @Environment(UserManager.self) private var userManager

    @State private var viewModel: ListsOverviewViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    ListsOverviewContentView(viewModel: viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("My Lists")
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
                    let vm = ListsOverviewViewModel(
                        taskListManager: taskListManager,
                        currentUserID: userManager.currentUser?.stableID ?? ""
                    )
                    vm.loadLists()
                    viewModel = vm
                }
            }
        }
    }
}

// MARK: - Content

private struct ListsOverviewContentView: View {
    @Bindable var viewModel: ListsOverviewViewModel

    var body: some View {
        List {
            ForEach(viewModel.filteredLists) { list in
                ListOverviewRow(
                    list: list,
                    totalItems: viewModel.itemCount(for: list),
                    completedItems: viewModel.completedCount(for: list)
                ) {
                    viewModel.beginEditing(list)
                }
            }
            .onDelete { indexSet in
                let filtered = viewModel.filteredLists
                for index in indexSet {
                    viewModel.deleteList(filtered[index])
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search lists")
        .overlay {
            if viewModel.lists.isEmpty {
                ContentUnavailableView(
                    "No Lists",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Create a list to start organizing your tasks.")
                )
            } else if viewModel.filteredLists.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            }
        }
        .sheet(item: $viewModel.editingList) { list in
            CreateListSheet(editing: list)
        }
        .onChange(of: viewModel.editingList) {
            // Refresh when the edit sheet is dismissed
            if viewModel.editingList == nil {
                viewModel.loadLists()
            }
        }
    }
}

// MARK: - Row

/// A single row in the lists overview: icon, name, completion progress, and an edit chevron.
private struct ListOverviewRow: View {
    let list: TaskList
    let totalItems: Int
    let completedItems: Int
    let onEdit: () -> Void

    private var listColor: Color {
        AppColor(rawValue: list.colorName)?.color ?? .blue
    }

    var body: some View {
        HStack {
            Image(systemName: list.iconName)
                .foregroundStyle(listColor)
                .frame(width: 24)

            VStack(alignment: .leading) {
                Text(list.name)

                Text("\(completedItems)/\(totalItems) completed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Edit", systemImage: "chevron.right", action: onEdit)
                .labelStyle(.iconOnly)
                .foregroundStyle(.secondary)
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

    return ListsOverviewView()
        .modelContainer(container)
        .environment(TaskListManager(modelContext: context))
        .environment(Router())
        .environment(ProjectManager(modelContext: context))
        .environment({
            let um = UserManager(modelContext: context)
            um.fetchOrCreateCurrentUser()
            return um
        }())
        .environment(HomeViewModel(
            taskListManager: TaskListManager(modelContext: context),
            projectManager: ProjectManager(modelContext: context),
            listItemManager: ListItemManager(modelContext: context)
        ))
}
