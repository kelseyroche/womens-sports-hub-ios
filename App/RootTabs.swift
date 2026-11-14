import SwiftUI

struct RootTabs: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            DayView(offset: 0)
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(AppTab.today)
            DayView(offset: 1)
                .tabItem { Label("Tomorrow", systemImage: "sunrise") }
                .tag(AppTab.tomorrow)
            UpcomingView()
                .tabItem { Label("Upcoming", systemImage: "calendar") }
                .tag(AppTab.upcoming)
            FollowingView()
                .tabItem { Label("Following", systemImage: "star") }
                .tag(AppTab.following)
            AccountView()
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
                .tag(AppTab.account)
        }
        .tint(Theme.ink)
        .toolbarBackground(Theme.chalk, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
