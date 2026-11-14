import Foundation
import Observation

enum AppTab: String, Hashable {
    case today, tomorrow, upcoming, following, account
}

@MainActor
@Observable
final class AppRouter {
    var tab: AppTab = .today

    init() {
        #if DEBUG
        if let raw = UserDefaults.standard.string(forKey: "rally-tab"), let launchTab = AppTab(rawValue: raw) {
            tab = launchTab
        }
        #endif
    }
}
