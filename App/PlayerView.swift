import SwiftUI
import RallyKit

struct PlayerView: View {
    let leagueID: String
    let athleteID: String
    @State private var player: PlayerDetail?
    @State private var failed = false
    private let client = ESPNClient()

    private var group: LeagueGroup { Catalog.group(Catalog.league(leagueID)!.group) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                if let player {
                    hero(player)
                    facts(player)
                    if !player.seasons.isEmpty {
                        label("Season stats")
                        table(first: "Season", labels: player.statLabels, rows: player.seasons.map { ($0.id, Text($0.label), $0.stats) })
                    }
                    if !player.recentGames.isEmpty {
                        label("Recent games")
                        table(first: "Game", labels: player.gameLabels, rows: player.recentGames.map { game in
                            (game.id, gameLink(game), game.stats)
                        })
                    }
                    if player.seasons.isEmpty && player.recentGames.isEmpty {
                        Text("ESPN has no stats for this player yet.").font(.subheadline).foregroundStyle(Theme.soft)
                    }
                } else if failed {
                    Text("This player couldn't be loaded.").font(.headline)
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
            player = await client.player(leagueID: leagueID, athleteID: athleteID)
            failed = player == nil
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(Theme.display(34))
            .padding(.top, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) { Rectangle().fill(Theme.ink).frame(height: 2) }
    }

    private func hero(_ p: PlayerDetail) -> some View {
        HStack(spacing: 16) {
            AsyncImage(url: p.headshot) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Text(p.name.split(separator: " ").compactMap { $0.first }.prefix(2).map(String.init).joined())
                    .font(.title2.weight(.heavy))
            }
            .frame(width: 84, height: 84)
            .background(Circle().fill(Theme.chalk))
            .clipShape(Circle())
            VStack(alignment: .leading, spacing: 6) {
                Text(p.name).font(Theme.display(52)).lineLimit(2).minimumScaleFactor(0.6)
                HStack(spacing: 4) {
                    if let position = p.position { Text(position) }
                    if p.position != nil && p.teamName != nil { Text("·") }
                    if let teamName = p.teamName {
                        if let teamID = p.teamID {
                            NavigationLink(value: TeamRoute(leagueID: leagueID, teamID: teamID)) {
                                Text(teamName).underline()
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text(teamName)
                        }
                    }
                }
                .font(.subheadline.weight(.semibold))
            }
            Spacer(minLength: 0)
            if let jersey = p.jersey {
                Text(jersey).font(Theme.display(90)).opacity(0.3)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: group.hue))
        .foregroundStyle(Theme.ink)
    }

    @ViewBuilder
    private func facts(_ p: PlayerDetail) -> some View {
        let items: [(String, String)] = [
            ("Height", p.height), ("Weight", p.weight), ("Age", p.age.map(String.init)),
            ("From", p.birthplace), ("Nationality", p.citizenship), ("Class", p.experience),
        ].compactMap { pair in pair.1.map { (pair.0, $0) } }
        if !items.isEmpty {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), alignment: .topLeading)], alignment: .leading, spacing: 14) {
                ForEach(items, id: \.0) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.0).font(.caption.weight(.semibold)).foregroundStyle(Theme.soft)
                        HStack(spacing: 8) {
                            if item.0 == "Nationality", let flag = p.flag {
                                AsyncImage(url: flag) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Color.clear
                                }
                                .frame(width: 28, height: 20)
                                .clipped()
                                .overlay(Rectangle().stroke(Theme.rule, lineWidth: 1))
                            }
                            Text(item.1).font(.headline)
                        }
                    }
                }
            }
        }
    }

    private func gameLink(_ game: PlayerGame) -> some View {
        let date = game.date.map { EasternTime.shortDate($0) } ?? ""
        return NavigationLink(value: GameRoute(leagueID: leagueID, eventID: game.eventID)) {
            Text("\(date) \(game.atVs) \(game.opponent) · \(game.result) \(game.score)")
                .multilineTextAlignment(.leading)
                .underline(color: Theme.ink.opacity(0.4))
        }
        .buttonStyle(.plain)
    }

    private func table(first: String, labels: [String], rows: [(String, some View, [String])]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .trailing, horizontalSpacing: 14, verticalSpacing: 0) {
                GridRow {
                    Text(first).gridColumnAlignment(.leading)
                    ForEach(labels, id: \.self) { Text($0) }
                }
                .font(.caption.weight(.heavy))
                .padding(.bottom, 6)
                ForEach(rows, id: \.0) { row in
                    GridRow {
                        row.1.font(.subheadline.weight(.bold)).gridColumnAlignment(.leading).frame(maxWidth: 220, alignment: .leading)
                        ForEach(Array(row.2.enumerated()), id: \.offset) { _, v in
                            Text(v).font(.subheadline).monospacedDigit()
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
}
