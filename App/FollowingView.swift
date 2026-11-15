import SwiftUI
import RallyKit

struct FollowingView: View {
    @Environment(FollowStore.self) private var follows
    @Environment(AppRouter.self) private var router
    #if DEBUG
    @State private var selected: GroupID = UserDefaults.standard.string(forKey: "rally-group").flatMap(GroupID.init(rawValue:)) ?? .wnba
    #else
    @State private var selected: GroupID = .wnba
    #endif
    @State private var teams: [GroupID: [Team]] = [:]
    @State private var query = ""
    private let client = ESPNClient()
    private let pageSize = 60

    private var group: LeagueGroup { Catalog.group(selected) }
    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }
    private var allTeams: [Team] { teams[selected] ?? [] }
    private var matches: [Team] {
        trimmedQuery.isEmpty ? allTeams : allTeams.filter { $0.name.localizedCaseInsensitiveContains(trimmedQuery) }
    }
    private var popular: [Team] { trimmedQuery.isEmpty ? matches.filter(\.popular) : [] }
    private var others: [Team] {
        let rest = trimmedQuery.isEmpty ? matches.filter { !$0.popular } : matches
        return trimmedQuery.isEmpty ? Array(rest.prefix(pageSize)) : rest
    }
    private var hiddenCount: Int {
        trimmedQuery.isEmpty ? matches.filter { !$0.popular }.count - others.count : 0
    }
    private var popularLabel: String { selected == .ncaaw || selected == .ncaav ? "Top 25" : "Popular" }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: -34) {
                        Text("Your")
                        Text("teams")
                    }
                    .font(Theme.display(88))
                    Text("\(follows.keys.count) \(follows.keys.count == 1 ? "team" : "teams") followed. Their games are pinned above everything else on Today.")
                        .font(.subheadline)
                    if !follows.keys.isEmpty {
                        Button("See the teams you follow") { router.tab = .account }
                            .font(.subheadline.weight(.bold))
                            .underline()
                    }
                    chips
                    searchField
                    if allTeams.isEmpty {
                        ProgressView().frame(maxWidth: .infinity).padding()
                    }
                    if !popular.isEmpty {
                        groupLabel(popularLabel)
                        ForEach(popular) { row($0) }
                    }
                    if !popular.isEmpty && !others.isEmpty { groupLabel("All teams") }
                    ForEach(others) { row($0) }
                    if !trimmedQuery.isEmpty && matches.isEmpty && !allTeams.isEmpty {
                        Text("No teams match \"\(trimmedQuery)\".").font(.subheadline).foregroundStyle(Theme.soft)
                    }
                    if hiddenCount > 0 {
                        Text("\(hiddenCount) more teams. Search to find any team.")
                            .font(.footnote)
                            .foregroundStyle(Theme.soft)
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.immediately)
            .rallyDestinations()
            .toolbar(.hidden, for: .navigationBar)
            .background(Theme.chalk.ignoresSafeArea())
            .foregroundStyle(Theme.ink)
            .task(id: selected) { await loadTeams(selected) }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
            TextField("Search \(allTeams.isEmpty ? "" : "\(allTeams.count) ")teams", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .overlay(Rectangle().stroke(Theme.ink, lineWidth: 2))
    }

    private func groupLabel(_ text: String) -> some View {
        Text(text).font(.subheadline.weight(.heavy)).foregroundStyle(Theme.soft).padding(.top, 8)
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Catalog.groups) { g in
                    Button {
                        selected = g.id
                        query = ""
                    } label: {
                        HStack(spacing: 6) {
                            Rectangle().fill(Color(hex: g.hue)).frame(width: 12, height: 12)
                                .overlay(Rectangle().stroke(selected == g.id ? Theme.chalk : Theme.ink, lineWidth: 1.5))
                            Text(g.label).font(.subheadline.weight(.bold))
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(selected == g.id ? Theme.ink : Color.clear)
                        .foregroundStyle(selected == g.id ? Theme.chalk : Theme.ink)
                        .overlay(Rectangle().stroke(Theme.ink, lineWidth: 2))
                    }
                }
            }
        }
    }

    private func row(_ team: Team) -> some View {
        let key = FollowKey.make(sport: group.sport, teamID: team.id)
        let on = follows.isFollowing(key)
        return HStack(spacing: 14) {
            NavigationLink(value: TeamRoute(leagueID: team.leagueID, teamID: team.id)) {
                HStack(spacing: 14) {
                    AsyncImage(url: team.logo) { image in
                        image.resizable().scaledToFit().padding(6)
                    } placeholder: {
                        Text(team.abbreviation).font(.system(size: 11, weight: .bold))
                    }
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.chalk))
                    .overlay(Circle().stroke(Theme.rule, lineWidth: 1))
                    HStack(spacing: 8) {
                        if let rank = team.rank {
                            Text("\(rank)")
                                .font(.caption.weight(.heavy))
                                .monospacedDigit()
                                .padding(.horizontal, 5)
                                .overlay(Rectangle().stroke(Theme.ink, lineWidth: 1.5))
                        }
                        Text(team.name).font(.title3.weight(.bold)).multilineTextAlignment(.leading)
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
            Button(on ? "Following" : "Follow") {
                follows.toggle(key, team: FollowedTeam(key: key, teamID: team.id, leagueID: team.leagueID, name: team.name, logo: team.logo))
            }
                .font(.subheadline.weight(.bold))
                .frame(minWidth: 96, minHeight: 44)
                .background(on ? Theme.ink : Color.clear)
                .foregroundStyle(on ? Theme.chalk : Theme.ink)
                .overlay(Rectangle().stroke(Theme.ink, lineWidth: 2))
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
    }

    private func loadTeams(_ id: GroupID) async {
        guard teams[id] == nil else { return }
        teams[id] = await client.teams(in: Catalog.group(id))
    }
}
