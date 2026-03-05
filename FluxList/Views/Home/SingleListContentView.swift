import SwiftUI
import SwiftData

/// An inline list-detail view shown on the home screen when a single list filter is active.
///
/// Provides an add-item text field at the top, favorite suggestion chips when the
/// field is focused, and a swipe-to-delete item list when unfocused. This is an
/// alternative to navigating to the full ``ListDetailView``.
struct SingleListContentView: View {
    /// The task list whose items are displayed.
    let list: TaskList
    let listItemManager: ListItemManager
    /// The `stableID` of the current user (set as `createdBy` on new items).
    let userID: String
    /// The user's favorite suggestions, shown as quick-add chips.
    let favoriteSuggestions: [String]

    @State private var newItemName = ""
    @FocusState private var isTextFieldFocused: Bool

    /// Items sorted with incomplete first, then by creation date.
    private var sortedItems: [ListItem] {
        (list.items ?? []).sorted { a, b in
            if a.isCompleted != b.isCompleted {
                return !a.isCompleted
            }
            return a.createdAt < b.createdAt
        }
    }

    /// Creates a new item in this list, either from a suggestion or from the text field.
    private func addItem(_ name: String? = nil) {
        let value = name ?? newItemName
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        listItemManager.createItem(name: trimmed, createdBy: userID, in: list)
        newItemName = ""
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Enter new task...", text: $newItemName)
                    .focused($isTextFieldFocused)
                    .submitLabel(.done)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.background, in: .rect(cornerRadius: 10))
                    .clipShape(.capsule)
                    .onSubmit { addItem() }

                Button("Add") { addItem() }
                    .bold()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppTheme.brandGradient, in: .rect(cornerRadius: 10))
                    .clipShape(.capsule)
            }
            .padding()

            Group {
                if isTextFieldFocused {
                    FavoriteSuggestionsView(
                        suggestions: favoriteSuggestions,
                        filter: newItemName,
                        existingItems: Set(sortedItems.map(\.name))
                    ) { suggestion in
                        addItem(suggestion)
                    }
                    .transition(.opacity)
                } else {
                    List {
                        ForEach(sortedItems) { item in
                            ListItemRow(item: item) {
                                withAnimation {
                                    listItemManager.toggleCompletion(item)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let item = sortedItems[index]
                                listItemManager.deleteItem(item)
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
    let list = lists.first!

    let users = try! context.fetch(FetchDescriptor<User>())
    let favorites = users.first?.favoriteSuggestions ?? []

    let userID = users.first?.id.uuidString ?? ""

    return SingleListContentView(
        list: list,
        listItemManager: ListItemManager(modelContext: context),
        userID: userID,
        favoriteSuggestions: favorites
    )
    .modelContainer(container)
}

