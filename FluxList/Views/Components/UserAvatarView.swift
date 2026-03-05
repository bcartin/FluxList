import SwiftUI

/// A circular avatar displaying the first initial of the user's name.
/// Falls back to the brand gradient if no custom color is provided.
struct UserAvatarView: View {
    /// The user's display name (the first letter is shown).
    let name: String
    /// An optional background color; defaults to the brand gradient.
    let color: Color?
    /// The diameter of the circle in points.
    let size: CGFloat

    init(name: String, color: Color? = nil, size: CGFloat = 28) {
        self.name = name
        self.color = color
        self.size = size
    }

    var body: some View {
        ZStack {
            if let color {
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
            } else {
                Circle()
                    .fill(AppTheme.brandGradient)
                    .frame(width: size, height: size)
            }

            Text(initials)
                .font(.system(size: size * 0.4))
                .bold()
                .foregroundStyle(.white)
        }
    }

    private var initials: String {
        let components = name.split(separator: " ")
        if let first = components.first?.first {
            return String(first).uppercased()
        }
        return "?"
    }
}

#Preview {
    HStack {
        UserAvatarView(name: "Robert")
        UserAvatarView(name: "Bernie", color: .orange)
    }
}
