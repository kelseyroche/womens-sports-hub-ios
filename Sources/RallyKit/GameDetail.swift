import Foundation

public enum TimelineKind: Sendable {
    case goal, yellow, red, sub, period, score
}

public struct TimelineItem: Sendable, Identifiable {
    public let id: String
    public let kind: TimelineKind
    public let clock: String
    public let title: String
    public let detail: String?
    public let teamID: String?
    public let score: String?
}

public struct StatRow: Sendable, Identifiable {
    public var id: String { label }
    public let label: String
    public let home: String
    public let away: String
}

public struct LineupPlayer: Sendable, Identifiable {
    public let id: String
    public let athleteID: String?
    public let name: String
    public let jersey: String
    public let position: String
    public let starter: Bool
    public let cameOn: Bool
    public let wentOff: Bool
}

public struct Lineup: Sendable, Identifiable {
    public var id: String { teamID }
    public let teamID: String
    public let teamName: String
    public let formation: String?
    public let players: [LineupPlayer]
}

public struct BoxScoreRow: Sendable, Identifiable {
    public let id: String
    public let athleteID: String?
    public let name: String
    public let stats: [String]
}

public struct BoxScore: Sendable, Identifiable {
    public var id: String { teamID }
    public let teamID: String
    public let teamName: String
    public let labels: [String]
    public let rows: [BoxScoreRow]
}

public struct DetailSide: Sendable {
    public let id: String
    public let name: String
    public let abbreviation: String
    public let logo: URL?
    public let score: Int?
    public let record: String?
    public let periods: [String]
}

public struct GameDetail: Sendable {
    public let leagueID: String
    public let sport: Sport
    public let state: GameState
    public let statusText: String
    public let startsAt: Date
    public let venue: String?
    public let attendance: Int?
    public let home: DetailSide
    public let away: DetailSide
    public let periodLabel: String?
    public let timeline: [TimelineItem]
    public let stats: [StatRow]
    public let lineups: [Lineup]
    public let boxScores: [BoxScore]
}

struct SummaryDTO: Decodable {
    struct Header: Decodable {
        struct Competition: Decodable {
            struct Status: Decodable {
                struct Kind: Decodable { let state: String; let shortDetail: String }
                let type: Kind
            }
            struct Competitor: Decodable {
                struct Team: Decodable {
                    struct Logo: Decodable { let href: String }
                    let id: String
                    let displayName: String
                    let abbreviation: String?
                    let logo: String?
                    let logos: [Logo]?
                }
                struct Value: Decodable { let displayValue: String? }
                let homeAway: String
                let score: String?
                let team: Team
                let record: [Value]?
                let linescores: [Value]?
            }
            let date: String
            let status: Status
            let competitors: [Competitor]
        }
        let competitions: [Competition]
    }
    struct GameInfo: Decodable {
        struct Venue: Decodable { let fullName: String? }
        let venue: Venue?
        let attendance: Int?
    }
    struct KeyEvent: Decodable {
        struct Kind: Decodable { let text: String; let type: String }
        struct Clock: Decodable { let displayValue: String? }
        struct TeamRef: Decodable { let id: String }
        struct Participant: Decodable {
            struct Athlete: Decodable { let displayName: String? }
            let athlete: Athlete?
        }
        let id: String
        let type: Kind
        let clock: Clock?
        let team: TeamRef?
        let participants: [Participant]?
        let shootout: Bool?
    }
    struct Play: Decodable {
        struct Period: Decodable { let number: Int }
        struct Clock: Decodable { let displayValue: String? }
        struct TeamRef: Decodable { let id: String }
        let id: String
        let text: String
        let scoringPlay: Bool?
        let homeScore: Int?
        let awayScore: Int?
        let period: Period?
        let clock: Clock?
        let team: TeamRef?
    }
    struct Boxscore: Decodable {
        struct TeamStats: Decodable {
            struct Ref: Decodable { let id: String }
            struct Stat: Decodable { let label: String?; let displayValue: String? }
            let team: Ref
            let statistics: [Stat]?
        }
        struct PlayerGroup: Decodable {
            struct Ref: Decodable { let id: String; let displayName: String }
            struct Group: Decodable {
                struct Entry: Decodable {
                    struct Athlete: Decodable { let id: String?; let displayName: String? }
                    let athlete: Athlete?
                    let stats: [String]?
                }
                let labels: [String]?
                let athletes: [Entry]?
            }
            let team: Ref
            let statistics: [Group]?
        }
        let teams: [TeamStats]?
        let players: [PlayerGroup]?
    }
    struct RosterTeam: Decodable {
        struct Ref: Decodable { let id: String; let displayName: String }
        struct Entry: Decodable {
            struct Athlete: Decodable { let id: String?; let displayName: String? }
            struct Position: Decodable { let abbreviation: String? }
            let starter: Bool?
            let jersey: String?
            let athlete: Athlete?
            let position: Position?
            let subbedIn: Bool?
            let subbedOut: Bool?
        }
        let team: Ref
        let formation: String?
        let roster: [Entry]?
    }
    let header: Header
    let gameInfo: GameInfo?
    let keyEvents: [KeyEvent]?
    let plays: [Play]?
    let boxscore: Boxscore?
    let rosters: [RosterTeam]?
}

extension GameDetail {
    static let soccerStats = ["Possession", "SHOTS", "ON GOAL", "Corner Kicks", "Saves", "Fouls", "Offsides", "Yellow Cards", "Red Cards", "Passes", "Tackles"]

    init?(league: League, summary: SummaryDTO) {
        guard
            let competition = summary.header.competitions.first,
            let homeC = competition.competitors.first(where: { $0.homeAway == "home" }),
            let awayC = competition.competitors.first(where: { $0.homeAway == "away" }),
            let state = GameState(espn: competition.status.type.state),
            let startsAt = ESPNDate.parse(competition.date)
        else { return nil }

        let sport = Catalog.group(league.group).sport
        let timeline: [TimelineItem]
        switch sport {
        case .soccer: timeline = Self.soccerTimeline(summary.keyEvents ?? [], homeID: homeC.team.id)
        case .basketball: timeline = Self.scoringPlays(summary.plays ?? [])
        case .volleyball: timeline = []
        }

        self.init(
            leagueID: league.id,
            sport: sport,
            state: state,
            statusText: competition.status.type.shortDetail,
            startsAt: startsAt,
            venue: summary.gameInfo?.venue?.fullName,
            attendance: (summary.gameInfo?.attendance ?? 0) > 0 ? summary.gameInfo?.attendance : nil,
            home: Self.side(homeC, state: state),
            away: Self.side(awayC, state: state),
            periodLabel: sport == .volleyball ? "Set" : sport == .basketball ? "Q" : nil,
            timeline: timeline,
            stats: Self.stats(summary, homeID: homeC.team.id, sport: sport),
            lineups: sport == .soccer ? Self.lineups(summary) : [],
            boxScores: sport == .soccer ? [] : Self.boxScores(summary)
        )
    }

    private static func side(_ c: SummaryDTO.Header.Competition.Competitor, state: GameState) -> DetailSide {
        let team = c.team
        let logo = team.logo ?? team.logos?.first?.href
        return DetailSide(
            id: team.id,
            name: team.displayName,
            abbreviation: team.abbreviation ?? String(team.displayName.prefix(3)).uppercased(),
            logo: logo.flatMap(URL.init(string:)),
            score: state == .upcoming ? nil : c.score.flatMap(Int.init),
            record: c.record?.first?.displayValue,
            periods: (c.linescores ?? []).map { $0.displayValue ?? "–" }
        )
    }

    private static func soccerTimeline(_ events: [SummaryDTO.KeyEvent], homeID: String) -> [TimelineItem] {
        var homeGoals = 0
        var awayGoals = 0
        var items: [TimelineItem] = []
        for event in events where event.shootout != true {
            let type = event.type.type
            let names = (event.participants ?? []).compactMap { $0.athlete?.displayName }
            let clock = event.clock?.displayValue ?? ""
            let teamID = event.team?.id
            if type.contains("goal") || type.contains("penalty---scored") {
                if teamID == homeID { homeGoals += 1 } else { awayGoals += 1 }
                let detail: String?
                if type.contains("own") {
                    detail = "Own goal"
                } else if names.count > 1 {
                    detail = "Assist \(names[1])"
                } else {
                    detail = event.type.text
                }
                items.append(TimelineItem(id: event.id, kind: .goal, clock: clock, title: names.first ?? event.type.text, detail: detail, teamID: teamID, score: "\(awayGoals)–\(homeGoals)"))
            } else if type.contains("yellow-card") || type.contains("red-card") {
                items.append(TimelineItem(id: event.id, kind: type.contains("red") ? .red : .yellow, clock: clock, title: names.first ?? event.type.text, detail: event.type.text, teamID: teamID, score: nil))
            } else if type == "substitution" {
                items.append(TimelineItem(id: event.id, kind: .sub, clock: clock, title: "\(names.first ?? "Player") on", detail: names.count > 1 ? "\(names[1]) off" : nil, teamID: teamID, score: nil))
            } else if ["halftime", "end-regular-time", "start-2nd-half", "kickoff"].contains(type) {
                items.append(TimelineItem(id: event.id, kind: .period, clock: clock, title: event.type.text, detail: nil, teamID: teamID, score: nil))
            }
        }
        return items.reversed()
    }

    private static func scoringPlays(_ plays: [SummaryDTO.Play]) -> [TimelineItem] {
        plays.filter { $0.scoringPlay == true }.map { play in
            TimelineItem(
                id: play.id,
                kind: .score,
                clock: "Q\(play.period?.number ?? 0) \(play.clock?.displayValue ?? "")",
                title: play.text,
                detail: nil,
                teamID: play.team?.id,
                score: "\(play.awayScore ?? 0)–\(play.homeScore ?? 0)"
            )
        }.reversed().prefix(80).map { $0 }
    }

    private static func stats(_ summary: SummaryDTO, homeID: String, sport: Sport) -> [StatRow] {
        let teams = summary.boxscore?.teams ?? []
        guard
            let home = teams.first(where: { $0.team.id == homeID }),
            let away = teams.first(where: { $0.team.id != homeID })
        else { return [] }
        let rows: [StatRow] = (home.statistics ?? []).compactMap { stat in
            guard
                let label = stat.label, let value = stat.displayValue,
                let other = away.statistics?.first(where: { $0.label == label })?.displayValue
            else { return nil }
            return StatRow(label: label, home: value, away: other)
        }
        guard sport == .soccer else { return rows }
        return soccerStats.flatMap { label in rows.filter { $0.label == label } }
    }

    private static func lineups(_ summary: SummaryDTO) -> [Lineup] {
        (summary.rosters ?? []).map { team in
            Lineup(
                teamID: team.team.id,
                teamName: team.team.displayName,
                formation: team.formation,
                players: (team.roster ?? []).enumerated().map { index, p in
                    LineupPlayer(
                        id: "\(team.team.id)-\(index)",
                        athleteID: p.athlete?.id,
                        name: p.athlete?.displayName ?? "Unknown",
                        jersey: p.jersey ?? "",
                        position: p.position?.abbreviation ?? "",
                        starter: p.starter == true,
                        cameOn: p.subbedIn == true,
                        wentOff: p.subbedOut == true
                    )
                }
            )
        }
    }

    private static func boxScores(_ summary: SummaryDTO) -> [BoxScore] {
        (summary.boxscore?.players ?? []).compactMap { team in
            guard let group = team.statistics?.first, let labels = group.labels else { return nil }
            let rows = (group.athletes ?? []).enumerated().compactMap { index, entry -> BoxScoreRow? in
                guard let stats = entry.stats, !stats.isEmpty else { return nil }
                return BoxScoreRow(id: "\(team.team.id)-\(index)", athleteID: entry.athlete?.id, name: entry.athlete?.displayName ?? "Unknown", stats: stats)
            }
            return rows.isEmpty ? nil : BoxScore(teamID: team.team.id, teamName: team.team.displayName, labels: labels, rows: rows)
        }
    }
}
