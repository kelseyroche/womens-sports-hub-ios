import SwiftUI
import RallyKit

struct TeamView: View {
    let leagueID: String
    let teamID: String
    @State private var team: TeamDetail?
    @State private var failed = false
    @Environment(FollowStore.self) private var follows
    private let client = ESPNClient()

    private var group: LeagueGroup { Catalog.group(Catalog.league(leagueID)!.group) }
    private static let positionOrder = ["Goalkeeper", "Defender", "Midfielder", "Forward", "Guard", "Center"]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                if let team {
                    hero(team)
                    if let coach = team.coach {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Head coach").font(.caption.weight(.semibold)).foregroundStyle(Theme.soft)
                            Text(coach).font(.headline)
                        }
                    }
                    if !team.upcoming.isEmpty {
                        label("Schedule")
                        ForEach(team.upcoming) { gameRow($0) }
                    }
                    if !team.recent.isEmpty {
                        label("Results")
                        ForEach(team.recent) { gameRow($0) }
                    }
                    label("Roster")
                    if team.roster.isEmpty {
                        Text("ESPN doesn't publish a roster for this team.").font(.subheadline).foregroundStyle(Theme.soft)
                    }
                    ForEach(groupedRoster(team.roster), id: \.0) { position, players in
                        Text(position).font(.subheadline.weight(.heavy)).foregroundStyle(Theme.soft)
                        ForEach(players) { playerRow($0) }
                    }
                } else if failed {
                    Text("This team couldn't be loaded.").font(.headline)
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
                }
            }
            .padding(16)
        }
        .background(Theme.chalk.ignoresSafeArea())
        .foregroundStyle(Theme.ink)
        .toolbarBackground(Theme.chalk, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            team = await client.team(leagueID: leagueID, teamID: teamID)
            failed = team == nil
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(Theme.display(34))
            .padding(.top, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) { Rectangle().fill(Theme.ink).frame(height: 2) }
    }

    private func hero(_ t: TeamDetail) -> some View {
        let key = FollowKey.make(sport: group.sport, teamID: t.id)
        let on = follows.isFollowing(key)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                AsyncImage(url: t.logo) { image in
                    image.resizable().scaledToFit().padding(10)
                } placeholder: {
                    Text(String(t.name.prefix(3)).uppercased()).font(.headline.weight(.heavy))
                }
                .frame(width: 84, height: 84)
                .background(Circle().fill(Theme.chalk))
                .clipShape(Circle())
                VStack(alignment: .leading, spacing: 6) {
                    Text(t.name).font(Theme.display(52)).lineLimit(2).minimumScaleFactor(0.6)
                    Text([t.standing, t.record].compactMap { $0 }.joined(separator: " · "))
                        .font(.subheadline.weight(.semibold))
                }
            }
            Button(on ? "Following" : "Follow team") { follows.toggle(key) }
                .font(.subheadline.weight(.bold))
                .padding(.horizontal, 18)
                .frame(minHeight: 44)
                .background(on ? Theme.ink : Theme.chalk)
                .foregroundStyle(on ? Theme.chalk : Theme.ink)
                .overlay(Rectangle().stroke(Theme.ink, lineWidth: 2))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: group.hue))
        .foregroundStyle(Theme.ink)
    }

    @ViewBuilder
    private func gameRow(_ game: TeamGame) -> some View {
        let content = HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(EasternTime.shortDate(game.date)).font(.subheadline.weight(.semibold))
                if game.state == .upcoming {
                    Text(EasternTime.clock(game.date)).font(.caption).foregroundStyle(Theme.soft)
                }
            }
            .frame(width: 74, alignment: .leading)
            AsyncImage(url: game.opponentLogo) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Color.clear
            }
            .frame(width: 26, height: 26)
            Text("\(game.isHome ? "vs" : "at") \(game.opponent)").font(.subheadline.weight(.semibold)).multilineTextAlignment(.leading)
            Spacer(minLength: 6)
            if game.state == .live {
                Text(game.statusText).font(.caption.weight(.bold)).padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Theme.lemon)
            }
            if let result = game.result {
                Text(result).font(.caption.weight(.heavy)).foregroundStyle(Theme.chalk)
                    .frame(minWidth: 22).padding(.vertical, 1)
                    .background(result == "W" ? Color(hex: "0EA66B") : result == "L" ? Color(hex: "B3261E") : Theme.soft)
            }
            if let score = game.score { Text(score).font(.subheadline.weight(.heavy)).monospacedDigit() }
        }
        .padding(.vertical, 8)
        .overlay(alignment: .top) { Rectangle().fill(Theme.rule).frame(height: 1) }
        if game.state == .upcoming {
            content
        } else {
            NavigationLink(value: GameRoute(leagueID: leagueID, eventID: game.eventID)) { content }.buttonStyle(.plain)
        }
    }

    private func groupedRoster(_ players: [RosterPlayer]) -> [(String, [RosterPlayer])] {
        var order: [String] = []
        var groups: [String: [RosterPlayer]] = [:]
        for player in players {
            if groups[player.position] == nil { order.append(player.position) }
            groups[player.position, default: []].append(player)
        }
        let rank = { (position: String) in Self.positionOrder.firstIndex(of: position) ?? Self.positionOrder.count }
        return order.sorted { rank($0) < rank($1) }.map { position in
            (position, groups[position]!.sorted { (Int($0.jersey ?? "") ?? 999) < (Int($1.jersey ?? "") ?? 999) })
        }
    }

    private func playerRow(_ p: RosterPlayer) -> some View {
        NavigationLink(value: PlayerRoute(leagueID: leagueID, athleteID: p.id)) {
            HStack(spacing: 12) {
                Text(p.jersey ?? "").font(.subheadline.weight(.heavy)).monospacedDigit().frame(width: 34, alignment: .leading)
                Text(p.name).font(.subheadline.weight(.semibold)).multilineTextAlignment(.leading)
                if let flag = p.flag {
                    AsyncImage(url: flag) { image in image.resizable().scaledToFill() } placeholder: { Color.clear }
                        .frame(width: 22, height: 15).clipped()
                        .overlay(Rectangle().stroke(Theme.rule, lineWidth: 1))
                }
                Spacer(minLength: 6)
                Text([p.height, p.experience ?? p.age.map(String.init)].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(Theme.soft)
            }
            .padding(.vertical, 7)
            .overlay(alignment: .top) { Rectangle().fill(Theme.rule).frame(height: 1) }
        }
        .buttonStyle(.plain)
    }
}
