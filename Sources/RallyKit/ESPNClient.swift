import Foundation

public actor ESPNClient {
    private let session: URLSession
    private let decoder = JSONDecoder()

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func games(on day: String) async -> [Game] {
        await withTaskGroup(of: [Game].self) { group in
            for league in Catalog.leagues {
                group.addTask { await self.games(in: league, on: day) }
            }
            var all: [Game] = []
            for await games in group { all.append(contentsOf: games) }
            return all.sorted { $0.startsAt < $1.startsAt }
        }
    }

    private func games(in league: League, on day: String) async -> [Game] {
        guard let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/\(league.path)/scoreboard?dates=\(day)&limit=200") else {
            return []
        }
        guard
            let (data, response) = try? await session.data(from: url),
            (response as? HTTPURLResponse)?.statusCode == 200,
            let board = try? decoder.decode(ScoreboardDTO.self, from: data)
        else { return [] }
        return (board.events ?? []).compactMap { Game(league: league, event: $0) }
    }

    private static let popularNational = [
        "United States", "England", "Spain", "Germany", "France", "Brazil", "Canada", "Japan", "Australia", "Sweden",
        "Netherlands", "Italy", "Norway", "Mexico", "Denmark", "Colombia", "Scotland", "Wales", "South Korea", "Nigeria",
    ]

    private static let rankingPaths: [GroupID: String] = [
        .ncaaw: "basketball/womens-college-basketball",
        .ncaav: "volleyball/womens-college-volleyball",
    ]

    public func teams(in group: LeagueGroup) async -> [Team] {
        async let ranks = rankings(for: group.id)
        let lists = await withTaskGroup(of: (Int, [Team]).self) { taskGroup in
            for (index, id) in group.teamSources.enumerated() {
                guard let league = Catalog.league(id) else { continue }
                taskGroup.addTask { (index, await self.teams(in: league)) }
            }
            var all: [(Int, [Team])] = []
            for await item in taskGroup { all.append(item) }
            return all.sorted { $0.0 < $1.0 }
        }
        let rankByID = await ranks
        var seen = Set<String>()
        var teams: [Team] = []
        for (index, list) in lists {
            for team in list where seen.insert(team.id).inserted {
                let rank = rankByID[team.id]
                let featuredEurope = group.id == .europe && group.teamSources.count > 1 && index == 0
                let featuredNational = group.id == .national && Self.popularNational.contains(team.name)
                teams.append(Team(
                    id: team.id,
                    name: team.name,
                    abbreviation: team.abbreviation,
                    logo: team.logo,
                    rank: rank,
                    popular: rank != nil || featuredEurope || featuredNational,
                    leagueID: team.leagueID
                ))
            }
        }
        return teams.sorted { a, b in
            if a.rank != nil || b.rank != nil {
                guard let ra = a.rank else { return false }
                guard let rb = b.rank else { return true }
                return ra < rb
            }
            if a.popular != b.popular { return a.popular }
            if group.id == .national, a.popular, b.popular {
                let ia = Self.popularNational.firstIndex(of: a.name) ?? Int.max
                let ib = Self.popularNational.firstIndex(of: b.name) ?? Int.max
                return ia < ib
            }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    private func rankings(for group: GroupID) async -> [String: Int] {
        guard
            let path = Self.rankingPaths[group],
            let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/\(path)/rankings"),
            let (data, response) = try? await session.data(from: url),
            (response as? HTTPURLResponse)?.statusCode == 200,
            let body = try? decoder.decode(RankingsDTO.self, from: data)
        else { return [:] }
        var ranks: [String: Int] = [:]
        for rank in body.rankings?.first?.ranks ?? [] { ranks[rank.team.id] = rank.current }
        return ranks
    }

    private func teams(in league: League) async -> [Team] {
        guard let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/\(league.path)/teams?limit=500") else {
            return []
        }
        guard
            let (data, response) = try? await session.data(from: url),
            (response as? HTTPURLResponse)?.statusCode == 200,
            let body = try? decoder.decode(TeamsDTO.self, from: data)
        else { return [] }
        let entries = body.sports?.first?.leagues?.first?.teams ?? []
        return entries.map { entry in
            let info = entry.team
            return Team(
                id: info.id,
                name: info.displayName,
                abbreviation: info.abbreviation ?? String(info.displayName.prefix(3)).uppercased(),
                logo: info.logos?.first.flatMap { URL(string: $0.href) },
                rank: nil,
                popular: false,
                leagueID: league.id
            )
        }
    }

    public func gameDetail(leagueID: String, eventID: String) async -> GameDetail? {
        guard
            let league = Catalog.league(leagueID),
            let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/\(league.path)/summary?event=\(eventID)"),
            let (data, response) = try? await session.data(from: url),
            (response as? HTTPURLResponse)?.statusCode == 200,
            let summary = try? decoder.decode(SummaryDTO.self, from: data)
        else { return nil }
        return GameDetail(league: league, summary: summary)
    }

    public func player(leagueID: String, athleteID: String) async -> PlayerDetail? {
        guard let league = Catalog.league(leagueID) else { return nil }
        let base = "https://site.web.api.espn.com/apis/common/v3/sports/\(league.path)/athletes/\(athleteID)"
        guard
            let bioURL = URL(string: base),
            let (bioData, bioResponse) = try? await session.data(from: bioURL),
            (bioResponse as? HTTPURLResponse)?.statusCode == 200,
            let bio = try? decoder.decode(AthleteDTO.self, from: bioData)
        else { return nil }
        var overview: OverviewDTO?
        if
            let url = URL(string: base + "/overview"),
            let (data, response) = try? await session.data(from: url),
            (response as? HTTPURLResponse)?.statusCode == 200
        {
            overview = try? decoder.decode(OverviewDTO.self, from: data)
        }
        return PlayerDetail(athlete: bio, overview: overview)
    }

    public func team(leagueID: String, teamID: String) async -> TeamDetail? {
        guard let league = Catalog.league(leagueID) else { return nil }
        let base = "https://site.api.espn.com/apis/site/v2/sports/\(league.path)/teams/\(teamID)"
        async let infoData = fetch(base)
        async let rosterData = fetch(base + "/roster")
        async let scheduleData = fetch(base + "/schedule")
        guard let info = await infoData.flatMap({ try? decoder.decode(TeamInfoDTO.self, from: $0) }) else { return nil }
        let roster = await rosterData.flatMap { try? decoder.decode(RosterDTO.self, from: $0) }
        let schedule = await scheduleData.flatMap { try? decoder.decode(ScheduleDTO.self, from: $0) }
        return TeamDetail(info: info, roster: roster, schedule: schedule, teamID: teamID)
    }

    private func fetch(_ string: String) async -> Data? {
        guard
            let url = URL(string: string),
            let (data, response) = try? await session.data(from: url),
            (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return data
    }
}
