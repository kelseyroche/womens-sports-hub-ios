import Foundation
import Observation
import RallyKit

@MainActor
@Observable
final class DayViewModel {
    let offset: Int
    private(set) var games: [Game] = []
    private(set) var isLoading = false
    private let client = ESPNClient()

    init(offset: Int) {
        self.offset = offset
    }

    var date: Date { EasternTime.addingDays(offset, to: Date()) }

    func load() async {
        isLoading = true
        games = await client.games(on: EasternTime.day(date))
        isLoading = false
    }
}
