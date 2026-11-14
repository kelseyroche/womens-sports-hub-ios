import SwiftUI
import RallyKit

struct PlayerRoute: Hashable {
    let leagueID: String
    let athleteID: String
}

struct GameRoute: Hashable {
    let leagueID: String
    let eventID: String
}

struct GameDetailView: View {
    private static let timelinePreview = 5
    let leagueID: String
    let eventID: String
    @State private var detail: GameDetail?
    @State private var failed = false
    @State private var timelineExpanded = false
    private let client = ESPNClient()

    private var group: LeagueGroup { Catalog.group(Catalog.league(leagueID)!.group) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                if let detail {
                    scoreboard(detail)
                    if detail.state == .upcoming {
                        Text("This game hasn't started. Scores, events and stats appear here once it does.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.soft)
                    }
                    timeline(detail)
                    stats(detail)
                    lineups(detail)
                    boxScores(detail)
                    if detail.sport == .volleyball {
                        Text("ESPN only publishes set scores for college volleyball.")
                            .font(.footnote)
                            .foregroundStyle(Theme.soft)
                    }
                } else if failed {
                    Text("This game couldn't be loaded. Pull down to try again.")
                        .font(.headline)
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
        .refreshable { await load() }
        .task {
            while !Task.isCancelled {
                await load()
                guard detail?.state == .live else { break }
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    private func load() async {
        let loaded = await client.gameDetail(leagueID: leagueID, eventID: eventID)
        if let loaded { detail = loaded } else if detail == nil { failed = true }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(Theme.display(34))
            .padding(.top, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) { Rectangle().fill(Theme.ink).frame(height: 2) }
    }

    private func scoreboard(_ d: GameDetail) -> some View {
        let live = d.state == .live
        let background = live ? Theme.ink : Color(hex: group.hue)
        let foreground = live ? Theme.chalk : Theme.ink
        let scores = [d.away.score ?? 0, d.home.score ?? 0]
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(Catalog.league(d.leagueID)?.name ?? "").font(.footnote.weight(.semibold))
                Spacer()
                if live {
                    Text(d.statusText)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Theme.lemon).foregroundStyle(Theme.ink)
                } else {
                    Text(d.state == .final ? d.statusText : "Upcoming")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .overlay(Rectangle().stroke(foreground, lineWidth: 1.5))
                }
            }
            ForEach(Array([d.away, d.home].enumerated()), id: \.offset) { index, side in
                HStack(spacing: 12) {
                    NavigationLink(value: TeamRoute(leagueID: d.leagueID, teamID: side.id)) {
                        HStack(spacing: 12) {
                            logo(side.logo, abbreviation: side.abbreviation, size: 52)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(side.name).font(.title3.weight(.heavy)).lineLimit(2).multilineTextAlignment(.leading)
                                if let record = side.record {
                                    Text(record).font(.caption.weight(.semibold)).opacity(0.75)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(d.state == .upcoming ? "" : "\(side.score ?? 0)")
                        .font(Theme.display(84))
                        .monospacedDigit()
                        .opacity(d.state == .upcoming || scores[index] >= scores.max()! ? 1 : 0.55)
                }
            }
            linescore(d, foreground: foreground)
            Text("\(EasternTime.longDate(d.startsAt)), \(EasternTime.clock(d.startsAt)) Eastern\(d.venue.map { " · \($0)" } ?? "")\(d.attendance.map { " · \($0.formatted()) attended" } ?? "")")
                .font(.caption)
        }
        .padding(18)
        .foregroundStyle(foreground)
        .background(background)
        .overlay(Rectangle().stroke(live ? Theme.ink : Color(hex: group.hue), lineWidth: 2))
    }

    @ViewBuilder
    private func linescore(_ d: GameDetail, foreground: Color) -> some View {
        let count = max(d.home.periods.count, d.away.periods.count)
        if let periodLabel = d.periodLabel, count > 0 {
            VStack(spacing: 0) {
                row(cells: [""] + (1...count).map { periodLabel == "Set" ? "Set \($0)" : "Q\($0)" })
                ForEach([d.away, d.home], id: \.id) { side in
                    row(cells: [side.abbreviation] + (0..<count).map { side.periods.indices.contains($0) ? side.periods[$0] : "–" })
                }
            }
            .font(.caption.weight(.bold))
        }
    }

    private func row(cells: [String]) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                Text(cell)
                    .frame(maxWidth: index == 0 ? 56 : .infinity, alignment: index == 0 ? .leading : .trailing)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 5)
        .overlay(alignment: .top) { Rectangle().frame(height: 1) }
    }

    private func logo(_ url: URL?, abbreviation: String, size: CGFloat) -> some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFit().padding(size * 0.12)
        } placeholder: {
            Text(abbreviation).font(.system(size: 11, weight: .bold))
        }
        .frame(width: size, height: size)
        .background(Circle().fill(Theme.chalk))
        .foregroundStyle(Theme.ink)
        .clipShape(Circle())
    }

    @ViewBuilder
    private func timeline(_ d: GameDetail) -> some View {
        if !d.timeline.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                label(d.sport == .basketball ? "Scoring plays" : "Match events")
                let collapsible = d.timeline.count > Self.timelinePreview + 3
                let shown = collapsible && !timelineExpanded ? Array(d.timeline.prefix(Self.timelinePreview)) : d.timeline
                ForEach(shown) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Text(item.clock).font(.subheadline.weight(.bold)).frame(width: 72, alignment: .leading)
                        mark(item.kind).frame(width: 18).padding(.top, 3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).font(item.kind == .goal || item.kind == .score ? .body.weight(.heavy) : .subheadline.weight(.semibold))
                            if let detail = item.detail { Text(detail).font(.caption).foregroundStyle(Theme.soft) }
                            if item.kind != .score, let name = teamName(item.teamID, d) { Text(name).font(.caption).foregroundStyle(Theme.soft) }
                        }
                        Spacer(minLength: 8)
                        if let score = item.score { Text(score).font(Theme.display(26)).monospacedDigit() }
                    }
                    .padding(.vertical, 10)
                    .padding(.leading, item.kind == .goal || item.kind == .score ? 10 : 0)
                    .background(item.kind == .period ? Theme.ink.opacity(0.06) : Color.clear)
                    .overlay(alignment: .leading) {
                        if item.kind == .goal || item.kind == .score { Rectangle().fill(Theme.ink).frame(width: 4) }
                    }
                    .overlay(alignment: .top) { Rectangle().fill(Theme.rule).frame(height: 1) }
                }
                if collapsible {
                    Button {
                        withAnimation { timelineExpanded.toggle() }
                    } label: {
                        Text(timelineExpanded ? "Show fewer" : "Show all \(d.timeline.count)")
                            .font(.headline)
                            .padding(.horizontal, 24)
                            .frame(minHeight: 48)
                            .overlay(Rectangle().stroke(Theme.ink, lineWidth: 2))
                    }
                    .padding(.top, 10)
                }
            }
        }
    }

    @ViewBuilder
    private func playerName(_ name: String, athleteID: String?, d: GameDetail) -> some View {
        if let athleteID {
            NavigationLink(value: PlayerRoute(leagueID: d.leagueID, athleteID: athleteID)) {
                Text(name).underline(color: Theme.ink.opacity(0.4))
            }
            .buttonStyle(.plain)
        } else {
            Text(name)
        }
    }

    private func teamName(_ id: String?, _ d: GameDetail) -> String? {
        id == d.home.id ? d.home.name : id == d.away.id ? d.away.name : nil
    }

    @ViewBuilder
    private func mark(_ kind: TimelineKind) -> some View {
        switch kind {
        case .goal, .score: Circle().fill(Theme.ink).frame(width: 14, height: 14)
        case .yellow: Rectangle().fill(Theme.lemon).frame(width: 11, height: 16).overlay(Rectangle().stroke(Theme.ink, lineWidth: 1.5))
        case .red: Rectangle().fill(Color(hex: "E0362C")).frame(width: 11, height: 16).overlay(Rectangle().stroke(Theme.ink, lineWidth: 1.5))
        case .sub: Image(systemName: "arrowtriangle.up.fill").font(.system(size: 12)).foregroundStyle(Color(hex: "0EA66B"))
        case .period: Rectangle().fill(Theme.ink).frame(width: 14, height: 2)
        }
    }

    @ViewBuilder
    private func stats(_ d: GameDetail) -> some View {
        if !d.stats.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                label("Team stats")
                HStack {
                    Text(d.away.name)
                    Spacer()
                    Text(d.home.name)
                }
                .font(.subheadline.weight(.bold))
                .padding(.vertical, 6)
                ForEach(d.stats) { stat in
                    let a = Double(stat.away)
                    let h = Double(stat.home)
                    let share = (a != nil && h != nil && a! + h! > 0) ? a! / (a! + h!) : 0.5
                    HStack(spacing: 12) {
                        Text(stat.away).font(.headline).monospacedDigit().frame(width: 50, alignment: .leading)
                        VStack(spacing: 4) {
                            Text(stat.label).font(.caption.weight(.semibold))
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Rectangle().fill(Theme.rule)
                                    Rectangle().fill(Theme.ink).frame(width: proxy.size.width * share)
                                }
                            }
                            .frame(height: 6)
                        }
                        Text(stat.home).font(.headline).monospacedDigit().frame(width: 50, alignment: .trailing)
                    }
                    .padding(.vertical, 8)
                    .overlay(alignment: .top) { Rectangle().fill(Theme.rule).frame(height: 1) }
                }
            }
        }
    }

    @ViewBuilder
    private func lineups(_ d: GameDetail) -> some View {
        if !d.lineups.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                label("Lineups")
                ForEach(d.lineups.sorted { $0.teamID == d.away.id && $1.teamID != d.away.id }) { lineup in
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .firstTextBaseline) {
                            NavigationLink(value: TeamRoute(leagueID: d.leagueID, teamID: lineup.teamID)) {
                                Text(lineup.teamName).font(.title3.weight(.heavy)).underline(color: Theme.ink.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                            if let formation = lineup.formation { Text(formation).font(.caption.weight(.semibold)).foregroundStyle(Theme.soft) }
                        }
                        ForEach([true, false], id: \.self) { starter in
                            let players = lineup.players.filter { $0.starter == starter }
                            if !players.isEmpty {
                                Text(starter ? "Starting" : "Bench").font(.caption).foregroundStyle(Theme.soft).padding(.top, 10)
                                ForEach(players) { p in
                                    HStack(spacing: 10) {
                                        Text(p.jersey).font(.subheadline.weight(.bold)).monospacedDigit().frame(width: 30, alignment: .leading)
                                        playerName(p.name, athleteID: p.athleteID, d: d)
                                        Spacer()
                                        Text(p.position).font(.caption).foregroundStyle(Theme.soft)
                                        Text(p.wentOff ? "Off" : p.cameOn ? "On" : "").font(.caption.weight(.heavy)).frame(width: 30, alignment: .trailing)
                                    }
                                    .padding(.vertical, 6)
                                    .overlay(alignment: .top) { Rectangle().fill(Theme.rule).frame(height: 1) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func boxScores(_ d: GameDetail) -> some View {
        if !d.boxScores.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                label("Box score")
                ForEach(d.boxScores) { box in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(box.teamName).font(.title3.weight(.heavy))
                        ScrollView(.horizontal, showsIndicators: false) {
                            Grid(alignment: .trailing, horizontalSpacing: 14, verticalSpacing: 0) {
                                GridRow {
                                    Text("Player").gridColumnAlignment(.leading)
                                    ForEach(box.labels, id: \.self) { Text($0) }
                                }
                                .font(.caption.weight(.heavy))
                                ForEach(box.rows) { row in
                                    GridRow {
                                        playerName(row.name, athleteID: row.athleteID, d: d).font(.subheadline.weight(.bold)).gridColumnAlignment(.leading)
                                        ForEach(Array(row.stats.enumerated()), id: \.offset) { _, v in
                                            Text(v).font(.subheadline).monospacedDigit()
                                        }
                                    }
                                    .padding(.vertical, 7)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
