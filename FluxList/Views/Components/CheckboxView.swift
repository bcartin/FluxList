import SwiftUI

/// A circular checkbox that toggles between an empty circle and a filled checkmark.
/// Uses the brand gradient fill when completed.
struct CheckboxView: View {
    /// Whether the associated item is marked as done.
    let isCompleted: Bool
    /// Called when the user taps the checkbox to toggle its state.
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isCompleted ? AnyShapeStyle(AppTheme.brandGradient) : AnyShapeStyle(.secondary))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        CheckboxView(isCompleted: false, action: {})
        CheckboxView(isCompleted: true, action: {})
    }
}
