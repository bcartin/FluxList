import SwiftUI

/// A dropdown menu that lets the user filter the home screen to show
/// all items, only items from a specific project, or only items from a specific list.
///
/// Displayed as a pill-shaped button in the toolbar. The button label updates
/// to reflect the currently active filter (e.g. "All", a project name, or a list name).
struct ViewFilterMenu: View {
    @Environment(HomeViewModel.self) private var viewModel

    var body: some View {
        Menu {
            // "All" resets the filter so every project and list is visible.
            // A checkmark appears when no specific filter is active.
            Button {
                viewModel.selectAll()
            } label: {
                if viewModel.filterLabel == "All" {
                    Label("All", systemImage: "checkmark")
                } else {
                    Text("All")
                }
            }

            // Lists each project as a selectable filter option.
            // The currently selected project shows a checkmark beside its name.
            if !viewModel.allProjects.isEmpty {
                Section("Projects") {
                    ForEach(viewModel.allProjects) { project in
                        Button {
                            viewModel.selectProject(project)
                        } label: {
                            if viewModel.selectedProject?.id == project.id {
                                Label(project.name, systemImage: "checkmark")
                            } else {
                                Text(project.name)
                            }
                        }
                    }
                }
            }

            // Lists each individual task list as a selectable filter option.
            // The currently selected list shows a checkmark beside its name.
            if !viewModel.allLists.isEmpty {
                Section("Lists") {
                    ForEach(viewModel.allLists) { list in
                        Button {
                            viewModel.selectList(list)
                        } label: {
                            if viewModel.selectedList?.id == list.id {
                                Label(list.name, systemImage: "checkmark")
                            } else {
                                Text(list.name)
                            }
                        }
                    }
                }
            }
        } label: {
            // Pill-shaped button that shows the active filter name.
            Text(viewModel.filterLabel)
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
        .foregroundStyle(.primary)
    }
}
