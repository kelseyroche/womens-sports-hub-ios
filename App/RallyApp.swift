import SwiftUI

@main
struct RallyApp: App {
    @State private var follows: FollowStore
    @State private var auth: AuthStore
    @State private var router = AppRouter()

    init() {
        let client = SupabaseConfig.makeClient()
        let follows = FollowStore(client: client)
        _follows = State(initialValue: follows)
        _auth = State(initialValue: AuthStore(client: client, follows: follows))
    }

    var body: some Scene {
        WindowGroup {
            RootTabs()
                .environment(follows)
                .environment(auth)
                .environment(router)
                .task { await auth.start() }
        }
    }
}
