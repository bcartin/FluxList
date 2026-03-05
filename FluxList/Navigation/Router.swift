import SwiftUI

/// Centralized navigation state shared across the app via the SwiftUI environment.
///
/// Manages both:
/// - **Push navigation** via ``path`` (a `NavigationPath` used with `NavigationStack`).
/// - **Sheet presentation** via boolean flags for each modal screen.
///
/// Views read and write these properties to trigger navigation without
/// tightly coupling to one another.
@MainActor @Observable
final class Router {
    /// The navigation stack path. Append ``Route`` values to push screens.
    var path = NavigationPath()

    // MARK: - Sheet presentation flags

    var isShowingCreateList = false
    var isShowingPaywall = false
    var isShowingProjects = false
    var isShowingListsOverview = false
    var isShowingFavorites = false
    var isShowingFriends = false
    var isShowingProfile = false
    var isShowingCreateAccount = false

    /// Pushes a new route onto the navigation stack.
    func navigate(to route: Route) {
        path.append(route)
    }

    /// Pops one level from the navigation stack (no-op if already at root).
    func goBack() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    /// Resets the navigation stack back to the root view.
    func goToRoot() {
        path = NavigationPath()
    }
}
