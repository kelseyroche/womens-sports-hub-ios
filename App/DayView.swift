import SwiftUI
import RallyKit

struct DayView: View {
    let offset: Int
    @State private var model: DayViewModel
    @State private var path = NavigationPath()
    @Environment(FollowStore.self) private var follows
    @Environment(AppRouter.self) private var router

    init(offset: Int) {
        self.offset = offset
        _model = State(initialValue: DayViewModel(offset: offset))
    }

    private var title: String { offset == 0 ? "Today" : "Tomorrow" }

    var body: some View {
        let pinned = model.games.filter { follows.isPinned($0) }
        let split = Featuring.split(model.games.filter { !follows.isPinned($0) })
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    header
                    if !model.games.isEmpty {
                        sectionLabel("Your teams")
                        if pinned.isEmpty {
                            invite
                        } else {
                            ForEach(pinned) { linked($0) }
                        }
                        if !split.featured.isEmpty {
                            sectionLabel("Everything else \(title.lowercased())")
                            ForEach(split.featured) { linked($0) }
                        }
                        if !split.more.isEmpty {
                            DisclosureGroup("All other college games (\(split.more.count))") {
                                ForEach(split.more) { linkedRow($0) }
                            }
                            .font(.headline)
                            .padding(.top, 8)
                        }
                    } else if !model.isLoading {
                        Text("Nothing on \(title.lowercased()).").font(Theme.display(56))
                    }
                }
                .padding(16)
            }
            .toolbar(.hidden, for: .navigationBar)
            .rallyDestinations()
            .background(Theme.chalk.ignoresSafeArea())
            .foregroundStyle(Theme.ink)
            .overlay {
                if model.isLoading && model.games.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading games").font(.subheadline)
                    }
                }
            }
            .refreshable { await model.load() }
            .task {
                await model.load()
                if offset == 0, path.isEmpty,
                   let index = UserDefaults.standard.string(forKey: "rally-open").flatMap(Int.init),
                   model.games.indices.contains(index) {
                    path.append(model.games[index])
                    if let player = UserDefaults.standard.string(forKey: "rally-player") {
                        path.append(PlayerRoute(leagueID: model.games[index].leagueID, athleteID: player))
                    }
                    if let team = UserDefaults.standard.string(forKey: "rally-team") {
                        path.append(TeamRoute(leagueID: model.games[index].leagueID, teamID: team))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func linked(_ game: Game) -> some View {
        if game.state == .upcoming {
            GameTile(game: game)
        } else {
            NavigationLink(value: game) { GameTile(game: game) }.buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func linkedRow(_ game: Game) -> some View {
        if game.state == .upcoming {
            CompactRow(game: game)
        } else {
            NavigationLink(value: game) { CompactRow(game: game) }.buttonStyle(.plain)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(EasternTime.longDate(model.date)).font(Theme.display(30))
            Text(title).font(Theme.display(88))
            if !model.games.isEmpty {
                let live = model.games.filter { $0.state == .live }.count
                Text("\(model.games.count) games.\(live > 0 ? " \(live) live now." : "") All times Eastern.")
                    .font(.subheadline)
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.display(34))
            .padding(.top, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) { Rectangle().fill(Theme.ink).frame(height: 2) }
    }

    private var invite: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Follow a team and its games pin here, above everything else.")
                .font(.headline)
            Button {
                router.tab = .following
            } label: {
                Text("Follow teams")
                    .font(.headline)
                    .foregroundStyle(Theme.chalk)
                    .padding(.horizontal, 24)
                    .frame(minHeight: 48)
                    .background(Theme.ink)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().stroke(Theme.ink, style: StrokeStyle(lineWidth: 2, dash: [6, 4])))
    }
}
