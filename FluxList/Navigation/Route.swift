import Foundation

/// Defines the possible push-navigation destinations used with `NavigationStack`.
///
/// Routes are `Hashable` so they can be appended to a `NavigationPath`.
/// The ``Router`` class manages the navigation stack using these values.
enum Route: Hashable {
    /// Navigate to the detail view for a specific task list, identified by its UUID.
    case listDetail(UUID)
    /// Navigate to the Pro upgrade paywall screen.
    case paywall

    /// Convenience factory that extracts the UUID from a ``TaskList``.
    static func listDetail(_ list: TaskList) -> Route {
        .listDetail(list.id)
    }
}
