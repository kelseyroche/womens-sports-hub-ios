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

if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "detail" {
    let detail = await client.gameDetail(leagueID: CommandLine.arguments[2], eventID: CommandLine.arguments[3])
    guard let detail else {
        print("detail failed to load")
        exit(1)
    }
    print("\(detail.away.name) \(detail.away.score ?? 0) - \(detail.home.score ?? 0) \(detail.home.name) [\(detail.state.rawValue)] \(detail.statusText)")
    print("timeline \(detail.timeline.count), stats \(detail.stats.count), lineups \(detail.lineups.count), box \(detail.boxScores.count), periods \(detail.home.periods)")
    for item in detail.timeline.prefix(3) { print("  \(item.clock) \(item.title) | \(item.detail ?? "") | \(item.score ?? "")") }
}

if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "player" {
    guard let player = await client.player(leagueID: CommandLine.arguments[2], athleteID: CommandLine.arguments[3]) else {
        print("player failed to load")
        exit(1)
    }
    print("\(player.name) #\(player.jersey ?? "-") \(player.position ?? "") \(player.teamName ?? "")")
    print("seasons \(player.seasons.count), recent \(player.recentGames.count), labels \(player.statLabels.count)")
    if let first = player.recentGames.first { print("  \(first.atVs) \(first.opponent) \(first.result) \(first.score) date=\(first.date != nil)") }
}

if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "team" {
    guard let team = await client.team(leagueID: CommandLine.arguments[2], teamID: CommandLine.arguments[3]) else {
        print("team failed to load")
        exit(1)
    }
    print("\(team.name) | \(team.standing ?? "") | \(team.record ?? "") | coach \(team.coach ?? "-")")
    print("roster \(team.roster.count), recent \(team.recent.count), upcoming \(team.upcoming.count)")
    for game in team.recent.prefix(2) { print("  \(game.result ?? "-") \(game.score ?? "") \(game.isHome ? "vs" : "at") \(game.opponent)") }
}
