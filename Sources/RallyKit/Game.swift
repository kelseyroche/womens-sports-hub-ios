import Foundation

public enum GameState: String, Sendable {
    case upcoming, live, final
}

public struct Side: Sendable, Identifiable {
    public let id: String
    public let name: String
    public let abbreviation: String
    public let logo: URL?
    public let score: Int?
    public let rank: Int?
}

public struct Game: Sendable, Identifiable {
    public let id: String
    public let eventID: String
    public let leagueID: String
    public let startsAt: Date
    public let state: GameState
    public let statusText: String
    public let home: Side
    public let away: Side
    public let venue: String?
}

struct ScoreboardDTO: Decodable {
    let events: [EventDTO]?
}

struct EventDTO: Decodable {
    struct Status: Decodable {
        struct Kind: Decodable {
            let state: String
            let shortDetail: String
        }
        let type: Kind
    }
    struct Competition: Decodable {
        struct Venue: Decodable { let fullName: String? }
        struct Competitor: Decodable {
            struct Rank: Decodable { let current: Int }
            struct Team: Decodable {
                let id: String
                let displayName: String
                let abbreviation: String?
                let logo: String?
            }
            let homeAway: String
            let score: String?
            let curatedRank: Rank?
            let team: Team
        }
        let venue: Venue?
        let competitors: [Competitor]
    }
    let id: String
    let date: String
    let status: Status
    let competitions: [Competition]
}

extension GameState {
    init?(espn: String) {
        switch espn {
        case "pre": self = .upcoming
        case "in": self = .live
        case "post": self = .final
        default: return nil
        }
    }
}

enum ESPNDate {
    static func parse(_ string: String) -> Date? {
        for format in ["yyyy-MM-dd'T'HH:mmXXXXX", "yyyy-MM-dd'T'HH:mm:ssXXXXX"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }
}

extension Game {
    init?(league: League, event: EventDTO) {
        guard
            let competition = event.competitions.first,
            let home = competition.competitors.first(where: { $0.homeAway == "home" }),
            let away = competition.competitors.first(where: { $0.homeAway == "away" }),
            let state = GameState(espn: event.status.type.state),
            let startsAt = ESPNDate.parse(event.date)
        else { return nil }
        self.init(
            id: "\(league.id)-\(event.id)",
            eventID: event.id,
            leagueID: league.id,
            startsAt: startsAt,
            state: state,
            statusText: event.status.type.shortDetail,
            home: Side(competitor: home, state: state),
            away: Side(competitor: away, state: state),
            venue: competition.venue?.fullName
        )
    }
}

extension Side {
    init(competitor: EventDTO.Competition.Competitor, state: GameState) {
        let team = competitor.team
        let rank = competitor.curatedRank?.current
        self.init(
            id: team.id,
            name: team.displayName,
            abbreviation: team.abbreviation ?? String(team.displayName.prefix(3)).uppercased(),
            logo: team.logo.flatMap(URL.init(string:)),
            score: state == .upcoming ? nil : competitor.score.flatMap(Int.init),
            rank: rank.flatMap { (1...25).contains($0) ? $0 : nil }
        )
    }
}

public enum Featuring {
    public static func split(_ games: [Game]) -> (featured: [Game], more: [Game]) {
        var featured: [Game] = []
        var more: [Game] = []
        for game in games {
            let crowded = Catalog.league(game.leagueID).map { Catalog.group($0.group).crowded } ?? false
            if !crowded || game.home.rank != nil || game.away.rank != nil {
                featured.append(game)
            } else {
                more.append(game)
            }
        }
        return (featured, more)
    }
}
