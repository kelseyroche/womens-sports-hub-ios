import Foundation
import RallyKit

let client = ESPNClient()
let day = EasternTime.day(Date())
let games = await client.games(on: day)

print("\(games.count) games on \(day)")
for league in Catalog.leagues {
    let count = games.filter { $0.leagueID == league.id }.count
    if count > 0 { print("  \(league.name): \(count)") }
}
for game in games.prefix(5) {
    let score = game.state == .upcoming ? "" : " \(game.away.score ?? 0)-\(game.home.score ?? 0)"
    print("  \(EasternTime.clock(game.startsAt)) \(game.away.name) at \(game.home.name)\(score) [\(game.state.rawValue)]")
}
