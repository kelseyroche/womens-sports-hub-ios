import Foundation
import Observation
import RallyKit

@MainActor
@Observable
final class TonightViewModel {
    private(set) var games: [Game] = []
    private(set) var isLoading = false
    private let client = ESPNClient()

    var featured: [Game] { Featuring.split(games).featured }
    var more: [Game] { Featuring.split(games).more }
    var liveCount: Int { games.filter { $0.state == .live }.count }

    func load() async {
        isLoading = true
        games = await client.games(on: EasternTime.day(Date()))
        isLoading = false
    }
}
