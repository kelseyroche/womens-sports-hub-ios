import Foundation
import Observation

enum AppTab: String, Hashable {
    case today, tomorrow, upcoming, following, account
}

@MainActor
@Observable
final class AppRouter {
    var tab: AppTab = UserDefaults.standard.string(forKey: "rally-tab").flatMap(AppTab.init(rawValue:)) ?? .today
}
