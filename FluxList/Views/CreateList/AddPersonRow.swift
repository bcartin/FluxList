import SwiftUI

/// A single row in the "Add Person" list, showing the person's avatar, name, email,
/// and either an "Add" button or a checkmark if they've already been added.
struct AddPersonRow: View {
    /// The person to display.
    let person: AddPersonViewModel.PersonResult
    /// `true` if this person has already been added to the shared list.
    let isAdded: Bool
    /// Called when the user taps the "+" button to add this person.
    let onAdd: () -> Void

    var body: some View {
        HStack {
            UserAvatarView(name: person.name, size: 32)

            VStack(alignment: .leading) {
                Text(person.name)
                    .font(.subheadline)
                    .bold()
                if !person.email.isEmpty {
                    Text(person.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isAdded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.gradientMid)
            } else {
                Button("Add", systemImage: "plus.circle.fill", action: onAdd)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(AppTheme.gradientMid)
            }
        }
    }
}
