import SwiftUI

/// A single row for a to-do item, showing a checkbox and the item name.
/// Completed items appear with strikethrough text and secondary color.
struct ListItemRow: View {
    /// The item to display.
    let item: ListItem
    /// Called when the checkbox is tapped.
    let onToggle: () -> Void

    var body: some View {
        HStack {
            CheckboxView(isCompleted: item.isCompleted, action: onToggle)

            Text(item.name)
                .strikethrough(item.isCompleted)
                .foregroundStyle(item.isCompleted ? .secondary : .primary)

            Spacer()
        }
        .padding(.vertical, 2)
    }
}
