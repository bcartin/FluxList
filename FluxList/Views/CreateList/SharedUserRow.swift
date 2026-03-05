import SwiftUI

/// Displays a shared user's avatar, name, and email with a remove button.
/// Used inside the "Shared With" section of the create/edit list form.
struct SharedUserRow: View {
    /// The user model to display.
    let user: User
    /// Called when the user taps the trash icon to remove this person from the list.
    let onRemove: () -> Void

    var body: some View {
        HStack {
            UserAvatarView(name: user.name, size: 32)

            VStack(alignment: .leading) {
                Text(user.name)
                    .font(.subheadline)
                    .bold()
                Text(user.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Remove", systemImage: "trash", action: onRemove)
                .labelStyle(.iconOnly)
                .foregroundStyle(.secondary)
        }
    }
}
