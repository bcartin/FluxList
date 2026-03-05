import SwiftUI

/// A grid of SF Symbol icons the user can assign to a task list.
/// The currently selected icon is highlighted with a tinted circle and the brand gradient.
struct IconPickerGrid: View {
    /// The icon currently chosen for the list.
    @Binding var selectedIcon: AppIcon

    /// 10-column adaptive grid for a compact icon picker layout.
    private let columns = Array(repeating: GridItem(.flexible()), count: 10)

    var body: some View {
        LazyVGrid(columns: columns) {
            ForEach(AppIcon.allCases) { icon in
                Button {
                    selectedIcon = icon
                } label: {
                    Image(systemName: icon.rawValue)
                        .font(.body)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(selectedIcon == icon ? AppTheme.gradientMid.opacity(0.15) : .clear)
                        )
                        .overlay {
                            if selectedIcon == icon {
                                Circle()
                                    .stroke(AppTheme.gradientMid, lineWidth: 1.5)
                                    .frame(width: 36, height: 36)
                            }
                        }
                }
                .foregroundStyle(selectedIcon == icon ? AnyShapeStyle(AppTheme.brandGradient) : AnyShapeStyle(.primary))
                .buttonStyle(.plain)
            }
        }
    }
}
