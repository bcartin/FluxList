import SwiftUI

/// A branded splash screen shown briefly at app launch.
///
/// Displays the app icon centered on a full-bleed gradient background
/// using the brand's cyan → purple → pink palette. The icon scales up
/// and fades in with a spring animation on appear.
struct SplashScreenView: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.gradientStart,
                    AppTheme.gradientMid,
                    AppTheme.gradientEnd
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Image("SplashIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)
                .clipShape(.rect(cornerRadius: 36))
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                .scaleEffect(isAnimating ? 1 : 0.7)
                .opacity(isAnimating ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
