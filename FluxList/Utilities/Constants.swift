import SwiftUI

// MARK: - Tier & Feature Constants

/// Limits applied to users on the free tier.
enum FreeTierLimits {
    /// Maximum number of task lists a free-tier user can create.
    static let maxLists = 2
}

/// Configuration constants for Pro-only features.
enum ProFeatures {
    /// Number of times an item must be added before it is auto-promoted to favorites.
    static let autoFavoriteThreshold = 3
}

// MARK: - Brand Theme

/// Brand colors and gradients used throughout the app UI.
/// Derived from the FluxList app icon's cyan → purple → pink palette.
enum AppTheme {
    static let gradientStart = Color(red: 0.4, green: 0.85, blue: 0.95)   // Cyan/Teal
    static let gradientMid = Color(red: 0.55, green: 0.45, blue: 0.9)     // Purple
    static let gradientEnd = Color(red: 0.85, green: 0.4, blue: 0.75)     // Pink/Magenta

    /// Full three-stop brand gradient used for prominent UI elements (e.g. paywall header).
    static let brandGradient = LinearGradient(
        colors: [gradientStart, gradientMid, gradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Mint accent color used for the checkbox checkmark and success states.
    static let accentMint = Color(red: 0.45, green: 0.95, blue: 0.85)

    /// A low-opacity version of the brand gradient for subtle background tints
    /// (e.g. the filter pill, card highlights).
    static let subtleGradient = LinearGradient(
        colors: [gradientStart.opacity(0.15), gradientEnd.opacity(0.15)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - List Colors

/// The palette of colors a user can assign to a ``TaskList``.
/// The raw value matches the string stored in ``TaskList/colorName``.
enum AppColor: String, CaseIterable, Identifiable, Sendable {
    case blue, orange, green, purple, red, coral, yellow, mint, teal, pink

    var id: String { rawValue }

    /// The SwiftUI `Color` corresponding to this palette entry.
    var color: Color {
        switch self {
        case .blue: .blue
        case .orange: .orange
        case .green: .green
        case .purple: .purple
        case .red: .red
        case .coral: Color(red: 1.0, green: 0.45, blue: 0.35)
        case .yellow: .yellow
        case .mint: .mint
        case .teal: .teal
        case .pink: .pink
        }
    }
}

/// The set of SF Symbol icons a user can assign to a ``TaskList``.
/// The raw value matches the string stored in ``TaskList/iconName``.
enum AppIcon: String, CaseIterable, Identifiable, Sendable {
    case listBullet = "list.bullet"
    case cart = "cart"
    case house = "house"
    case briefcase = "briefcase"
    case calendar = "calendar"
    case face = "face.smiling"
    case star = "star"
    case heart = "heart"
    case book = "book"
    case music = "music.note"
    case camera = "camera"
    case airplane = "airplane"
    case message = "message"
    case carside = "car.side"
    case globe = "globe"
    case gamecontroller = "gamecontroller"
    case gift = "gift"
    case movieclapper = "movieclapper"
    case theatermasks = "theatermasks"
    case link = "link"

    var id: String { rawValue }
}
