import SwiftUI
import SwiftData

/// A modal sheet for managing projects (create, rename, delete).
///
/// Projects are used to group related ``TaskList`` items. The view shows a
/// searchable list with swipe-to-delete and alerts for creating and renaming.
struct ProjectsListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProjectManager.self) private var projectManager

    @State private var viewModel: ProjectsListViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    ProjectsContentView(viewModel: viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Projects")
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
                            Label("New Project", systemImage: "plus")
                                .bold()
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(AppTheme.brandGradient, in: .circle)
                                .fixedSize()
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .task {
                if viewModel == nil {
                    let vm = ProjectsListViewModel(projectManager: projectManager)
                    vm.loadProjects()
                    viewModel = vm
                }
            }
        }
    }
}

// MARK: - Content

/// The searchable projects list body with create/rename alerts.
private struct ProjectsContentView: View {
    @Bindable var viewModel: ProjectsListViewModel

    var body: some View {
        List {
            ForEach(viewModel.filteredProjects) { project in
                ProjectRow(project: project) {
                    viewModel.beginEditing(project)
                }
            }
            .onDelete { indexSet in
                let filtered = viewModel.filteredProjects
                for index in indexSet {
                    viewModel.deleteProject(filtered[index])
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search projects")
        .overlay {
            if viewModel.projects.isEmpty {
                ContentUnavailableView(
                    "No Projects",
                    systemImage: "folder",
                    description: Text("Projects help you organize your lists into groups.")
                )
            } else if viewModel.filteredProjects.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            }
        }
        .alert("Rename Project", isPresented: $viewModel.isShowingEditAlert) {
            TextField("Project name", text: $viewModel.editedName)
            Button("Save") {
                viewModel.confirmEdit()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a new name for this project.")
        }
        .alert("New Project", isPresented: $viewModel.isShowingCreateAlert) {
            TextField("Project name", text: $viewModel.newProjectName)
            Button("Create") {
                viewModel.confirmCreate()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a name for the new project.")
        }
    }
}

// MARK: - Project Row

/// A single row showing a project's folder icon, name, and an edit chevron.
private struct ProjectRow: View {
    let project: Project
    let onEdit: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundStyle(AppTheme.gradientMid)

            Text(project.name)

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

    let _ = [
        Project(name: "Website Redesign"),
        Project(name: "Mobile App"),
        Project(name: "Marketing Campaign")
    ].forEach { context.insert($0) }

    ProjectsListView()
        .modelContainer(container)
        .environment(ProjectManager(modelContext: context))
}
