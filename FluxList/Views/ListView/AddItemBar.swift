import SwiftUI

/// A text field and "Add" button used at the top of list detail views.
///
/// Pressing Return submits the item and keeps the keyboard open for rapid entry.
/// The `isFocused` binding controls whether the keyboard is shown and whether
/// the parent view displays favorite suggestion chips.
struct AddItemBar: View {
    /// Bound to the view model's new-item text.
    @Binding var text: String
    /// Focus binding used to keep the keyboard open after submission.
    var isFocused: FocusState<Bool>.Binding
    /// Called when the user taps "Add" or presses Return.
    let onAdd: () -> Void

    var body: some View {
        HStack {
            TextField("Enter new task...", text: $text)
                .focused(isFocused)
                .submitLabel(.done)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.background, in: .rect(cornerRadius: 10))
                .clipShape(.capsule)
                .onSubmit {
                    onAdd()
                    isFocused.wrappedValue = true
                }

            Button("Add", action: onAdd)
                .bold()
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(AppTheme.brandGradient, in: .capsule)
                .clipShape(.capsule)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
