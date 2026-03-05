import OSLog
import SwiftUI
import SwiftData

private let logger = Logger(subsystem: "com.fluxlist", category: "ListDetailView")

/// The full-screen detail view for a single task list, pushed onto the navigation stack.
///
/// Loads its ``TaskList`` from SwiftData using the provided `listID`, then delegates
/// item management to a ``ListViewModel``. Includes an add-item bar, favorite
/// suggestion chips, a swipe-to-delete item list, and toolbar actions for editing
/// the list or clearing completed items.
struct ListDetailView: View {
    @Environment(Router.self) private var router
    @Environment(ListItemManager.self) private var listItemManager
    @Environment(UserManager.self) private var userManager
    @Environment(\.modelContext) private var modelContext

    /// The UUID of the list to display, passed via ``Route/listDetail(_:)-swift.enum.case``.
    let listID: UUID

    /// Created in `onAppear` after the list is fetched from SwiftData.
    @State private var viewModel: ListViewModel?
    @State private var isShowingEditList = false

    var body: some View {
        Group {
            if let viewModel {
                ListDetailContentView(viewModel: viewModel)
            } else {
                ContentUnavailableView("List not found", systemImage: "list.bullet")
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                if let viewModel {
                    Text(viewModel.taskList.name)
                        .font(.subheadline)
                        .bold()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(AppTheme.subtleGradient)
                        )
                        .overlay(
                            Capsule()
                                .stroke(AppTheme.gradientMid.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .topBarTrailing) {
                if let viewModel {
                    Menu {
                        Button("Edit List", systemImage: "pencil") {
                            isShowingEditList = true
                        }
                        Button("Clear completed", systemImage: "trash", role: .destructive) {
                            withAnimation {
                                viewModel.deleteCompletedItems()
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .bold()
                            .foregroundStyle(.white)
                            .padding(16)
                            .background(AppTheme.brandGradient, in: .circle)
                    }
                }
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingEditList) {
            if let viewModel {
                CreateListSheet(editing: viewModel.taskList)
            }
        }
        .onAppear {
            if viewModel == nil {
                let searchID = listID
                let descriptor = FetchDescriptor<TaskList>(
                    predicate: #Predicate { $0.id == searchID }
                )
                do {
                    if let list = try modelContext.fetch(descriptor).first {
                        viewModel = ListViewModel(taskList: list, listItemManager: listItemManager)
                    }
                } catch {
                    logger.error("Failed to fetch list: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Content

/// The body of the list detail: add-item bar, suggestion chips / item list, and keyboard toolbar.
private struct ListDetailContentView: View {
    @Bindable var viewModel: ListViewModel
    @Environment(UserManager.self) private var userManager
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            AddItemBar(text: $viewModel.newItemName, isFocused: $isTextFieldFocused) {
                addItem()
            }

            Group {
                if isTextFieldFocused {
                    FavoriteSuggestionsView(
                        suggestions: userManager.currentUser?.favoriteSuggestions ?? [],
                        filter: viewModel.newItemName,
                        existingItems: Set(viewModel.sortedItems.map(\.name))
                    ) { suggestion in
                        addItem(suggestion)
                    }
                    .transition(.opacity)
                } else {
                    List {
                        ForEach(viewModel.sortedItems) { item in
                            ListItemRow(item: item) {
                                withAnimation {
                                    viewModel.toggleCompletion(item)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let item = viewModel.sortedItems[index]
                                viewModel.deleteItem(item)
                            }
                        }
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isTextFieldFocused)
        }
        .background(.secondaryBackground)
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                Button("Done") {
                    isTextFieldFocused = false
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .background(AppTheme.brandGradient, in: .capsule)
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }

    /// Adds an item using either an explicit name (from suggestions) or the text field value.
    private func addItem(_ name: String? = nil) {
        if let name {
            viewModel.newItemName = name
        }
        viewModel.addItem(createdBy: userManager.currentUser?.stableID ?? "")
    }
}
// MARK: - Preview

#Preview {
    let schema = Schema([User.self, Project.self, TaskList.self, ListItem.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    let context = container.mainContext

    SampleData.populateSampleData(in: context)

    let lists = try! context.fetch(FetchDescriptor<TaskList>())
    let listID = lists.first!.id

    return NavigationStack {
        ListDetailView(listID: listID)
    }
    .modelContainer(container)
    .environment(Router())
    .environment(ListItemManager(modelContext: context))
    .environment({
        let um = UserManager(modelContext: context)
        um.fetchOrCreateCurrentUser()
        return um
    }())
}

