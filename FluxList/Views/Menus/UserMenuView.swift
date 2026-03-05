import SwiftUI

/// A dropdown menu anchored to the user-avatar icon in the toolbar's leading position.
///
/// Provides quick access to:
/// - **Profile** – edit name and email.
/// - **Lists** – manage all created lists.
/// - **Projects** – manage project groups.
/// - **Favorites** – manage favorite item suggestions.
/// - **Friends** – view and manage friends (Pro only).
/// - **Upgrade to Pro** – opens the paywall (free tier only).
struct UserMenu: View {
    @Environment(Router.self) private var router
    @Environment(UserManager.self) private var userManager
    @Environment(StoreKitManager.self) private var storeKitManager

    var body: some View {
        Menu {
            // User header section
            Section {
                Button {
                    router.isShowingProfile = true
                } label: {
                    Label(userManager.currentUser?.name ?? "User", systemImage: "person.circle.fill")
                }
            }

            // Navigation items
            Section {
                Button("Lists", systemImage: "list.bullet") {
                    router.isShowingListsOverview = true
                }
                Button("Projects", systemImage: "folder") {
                    router.isShowingProjects = true
                }
                Button("Favorites", systemImage: "heart") {
                    router.isShowingFavorites = true
                }
                if storeKitManager.isProUser {
                    Button("Friends", systemImage: "person.2") {
                        router.isShowingFriends = true
                    }
                }
            }

            if !storeKitManager.isProUser {
                // Upgrade
                Section {
                    Button("Upgrade to Pro", systemImage: "star.fill") {
                        router.isShowingPaywall = true
                    }
                }
            }
        } label: {
            Image(systemName: "person.circle")
                .font(.title)
                .foregroundStyle(AppTheme.brandGradient)
        }
    }
}
