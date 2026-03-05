import SwiftUI
import SwiftData

/// A modal sheet for creating a new task list or editing an existing one.
///
/// The sheet contains a form with fields for name, project assignment, color, icon,
/// and shared users. It delegates persistence to ``CreateListViewModel`` and
/// refreshes the home screen data on save.
struct CreateListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(Router.self) private var router
    @Environment(TaskListManager.self) private var taskListManager
    @Environment(ProjectManager.self) private var projectManager
    @Environment(UserManager.self) private var userManager
    @Environment(HomeViewModel.self) private var homeViewModel

    /// Pass a `TaskList` to open the sheet in edit mode, or leave nil for create mode.
    var editing: TaskList?

    /// Created lazily in `onAppear` so environment values are available.
    @State private var viewModel: CreateListViewModel?

    private var currentUserID: String {
        userManager.currentUser?.stableID ?? ""
    }

    var body: some View {
        NavigationStack {
            if let viewModel {
                CreateListFormView(viewModel: viewModel)
                    .navigationTitle(viewModel.isEditing ? "Edit List" : "New List")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { dismiss() }
                        }
                        .sharedBackgroundVisibility(.hidden)
                        ToolbarItem(placement: .confirmationAction) {
                            Button {
                                viewModel.save(createdByUserID: currentUserID)
                                homeViewModel.loadData()
                                dismiss()
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(AppTheme.brandGradient)
                            }
                            .disabled(!viewModel.canSave)
                        }
                        .sharedBackgroundVisibility(.hidden)
                    }
            }
        }
        .onAppear {
            if viewModel == nil {
                if let editing {
                    viewModel = CreateListViewModel(
                        taskListManager: taskListManager,
                        projectManager: projectManager,
                        editing: editing
                    )
                } else {
                    viewModel = CreateListViewModel(
                        taskListManager: taskListManager,
                        projectManager: projectManager
                    )
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Form Content

/// The form content of the create/edit list sheet, extracted into its own view
/// so the ``CreateListSheet`` can manage toolbar and presentation separately.
private struct CreateListFormView: View {
    @Bindable var viewModel: CreateListViewModel
    @Environment(UserManager.self) private var userManager
    @Environment(StoreKitManager.self) private var storeKitManager
    @State private var isShowingAddPerson = false

    var body: some View {
        let _ = resolveNamesIfNeeded()

        Form {
            Section("Name") {
                TextField("e.g. Weekend Plans", text: $viewModel.name)
            }

            Section("Project") {
                Picker("Project", selection: $viewModel.selectedProject) {
                    Text("None").tag(nil as Project?)
                    ForEach(viewModel.availableProjects) { project in
                        Text(project.name).tag(project as Project?)
                    }
                }
            }

            Section("Color") {
                ColorPickerRow(selectedColor: $viewModel.selectedColor)
            }

            Section("Icon") {
                IconPickerGrid(selectedIcon: $viewModel.selectedIcon)
            }

            if storeKitManager.isProUser { Section("Shared With") {
                let currentID = userManager.currentUser?.stableID
                ForEach(viewModel.sharedUserIDs.filter { $0 != currentID }, id: \.self) { userID in
                    let displayName = userManager.userNameCache[userID] ?? userID
                    HStack {
                        UserAvatarView(name: displayName, size: 32)
                        Text(displayName)
                            .font(.subheadline)
                        Spacer()
                        Button("Remove", systemImage: "trash") {
                            viewModel.removeSharedUserID(userID)
                        }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)
                    }
                }

                Button("Add person", systemImage: "plus") {
                    isShowingAddPerson = true
                }
                .foregroundStyle(AppTheme.gradientMid)
            } }
        }
        .navigationDestination(isPresented: $isShowingAddPerson) {
            AddPersonView(sharedUserIDs: $viewModel.sharedUserIDs)
        }
    }

    /// Ensures display names are resolved for all shared user IDs so the list
    /// can show human-readable names instead of raw IDs.
    private func resolveNamesIfNeeded() {
        let ids = viewModel.sharedUserIDs
        if ids.contains(where: { userManager.userNameCache[$0] == nil }) {
            userManager.resolveUserNames(for: ids)
        }
    }
}
#Preview {
    let container = SampleData.sampleContainer
    let context = container.mainContext

    CreateListSheet()
        .modelContainer(container)
        .environment(Router())
        .environment(TaskListManager(modelContext: context))
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

