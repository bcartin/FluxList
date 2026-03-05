import SwiftUI

/// A circular "+" button anchored to the bottom of the home screen.
/// Tapping it opens the "Create List" sheet.
struct FloatingActionButton: View {
    let action: () -> Void

    var body: some View {
        Button("New list", systemImage: "plus", action: action)
            .labelStyle(.iconOnly)
            .font(.title2)
            .bold()
            .foregroundStyle(.white)
            .frame(width: 56, height: 56)
            .background(AppTheme.brandGradient, in: .circle)
            .shadow(color: AppTheme.gradientMid.opacity(0.35), radius: 10, y: 5)
            .padding()
    }
}

#Preview {
    FloatingActionButton(action: {})
}
