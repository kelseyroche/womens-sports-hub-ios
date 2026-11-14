import Foundation

public struct PlayerGame: Sendable, Identifiable {
    public var id: String { eventID }
    public let eventID: String
    public let date: Date?
    public let opponent: String
    public let atVs: String
    public let result: String
    public let score: String
    public let stats: [String]
}

public struct PlayerSeason: Sendable, Identifiable {
    public var id: String { label }
    public let label: String
    public let stats: [String]
}

public struct PlayerDetail: Sendable {
    public let id: String
    public let name: String
    public let jersey: String?
    public let position: String?
    public let height: String?
    public let weight: String?
    public let age: Int?
    public let birthplace: String?
    public let citizenship: String?
    public let flag: URL?
    public let experience: String?
    public let headshot: URL?
    public let teamName: String?
    public let teamID: String?
    public let statLabels: [String]
    public let seasons: [PlayerSeason]
    public let gameLabels: [String]
    public let recentGames: [PlayerGame]
}

struct AthleteDTO: Decodable {
    struct Athlete: Decodable {
        struct Position: Decodable { let displayName: String? }
        struct Headshot: Decodable { let href: String? }
        struct Team: Decodable { let id: String?; let displayName: String? }
        struct Flag: Decodable { let href: String?; let alt: String? }
        let id: String
        let displayName: String
        let jersey: String?
        let position: Position?
        let displayHeight: String?
        let displayWeight: String?
        let age: Int?
        let displayBirthPlace: String?
        let citizenship: String?
        let flag: Flag?
        let displayExperience: String?
        let headshot: Headshot?
        let team: Team?
    }
    let athlete: Athlete?
}

struct OverviewDTO: Decodable {
    struct Statistics: Decodable {
        struct Split: Decodable { let displayName: String; let stats: [String] }
        let labels: [String]?
        let splits: [Split]?
    }
    struct GameLog: Decodable {
        struct Group: Decodable {
            struct Entry: Decodable { let eventId: String; let stats: [String] }
            let labels: [String]?
            let events: [Entry]?
        }
        struct Event: Decodable {
            struct Opponent: Decodable { let displayName: String? }
            let gameDate: String?
            let atVs: String?
            let gameResult: String?
            let homeTeamId: String?
            let homeTeamScore: String?
            let awayTeamScore: String?
            let opponent: Opponent?
        }
        let statistics: [Group]?
        let events: [String: Event]?
    }
    let statistics: Statistics?
    let gameLog: GameLog?
}

extension PlayerDetail {
    init?(athlete body: AthleteDTO, overview: OverviewDTO?) {
        guard let athlete = body.athlete else { return nil }
        let teamID = athlete.team?.id
        let group = overview?.gameLog?.statistics?.first
        let games: [PlayerGame] = (group?.events ?? []).compactMap { entry in
            guard let meta = overview?.gameLog?.events?[entry.eventId] else { return nil }
            let isHome = meta.homeTeamId == teamID
            let own = (isHome ? meta.homeTeamScore : meta.awayTeamScore) ?? "0"
            let other = (isHome ? meta.awayTeamScore : meta.homeTeamScore) ?? "0"
            return PlayerGame(
                eventID: entry.eventId,
                date: meta.gameDate.flatMap(ESPNDate.parse),
                opponent: meta.opponent?.displayName ?? "Opponent",
                atVs: meta.atVs ?? "vs",
                result: meta.gameResult ?? "",
                score: "\(own)–\(other)",
                stats: entry.stats
            )
        }
        self.init(
            id: athlete.id,
            name: athlete.displayName,
            jersey: athlete.jersey,
            position: athlete.position?.displayName,
            height: athlete.displayHeight,
            weight: athlete.displayWeight,
            age: athlete.age,
            birthplace: athlete.displayBirthPlace,
            citizenship: athlete.citizenship ?? athlete.flag?.alt,
            flag: athlete.flag?.href.flatMap(URL.init(string:)),
            experience: athlete.displayExperience,
            headshot: athlete.headshot?.href.flatMap(URL.init(string:)),
            teamName: athlete.team?.displayName,
            teamID: athlete.team?.id,
            statLabels: overview?.statistics?.labels ?? [],
            seasons: (overview?.statistics?.splits ?? []).map { PlayerSeason(label: $0.displayName, stats: $0.stats) },
            gameLabels: group?.labels ?? [],
            recentGames: games
        )
    }
}
