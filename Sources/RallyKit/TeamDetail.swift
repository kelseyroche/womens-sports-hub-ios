import Foundation

public struct RosterPlayer: Sendable, Identifiable {
    public let id: String
    public let name: String
    public let jersey: String?
    public let position: String
    public let height: String?
    public let age: Int?
    public let experience: String?
    public let flag: URL?
    public let country: String?
}

public struct TeamGame: Sendable, Identifiable {
    public var id: String { eventID }
    public let eventID: String
    public let date: Date
    public let isHome: Bool
    public let opponent: String
    public let opponentLogo: URL?
    public let state: GameState
    public let statusText: String
    public let score: String?
    public let result: String?
}

public struct TeamDetail: Sendable {
    public let id: String
    public let name: String
    public let logo: URL?
    public let record: String?
    public let standing: String?
    public let coach: String?
    public let roster: [RosterPlayer]
    public let recent: [TeamGame]
    public let upcoming: [TeamGame]
}

struct TeamInfoDTO: Decodable {
    struct Team: Decodable {
        struct Logo: Decodable { let href: String }
        struct Record: Decodable {
            struct Item: Decodable { let summary: String? }
            let items: [Item]?
        }
        let id: String
        let displayName: String
        let logos: [Logo]?
        let standingSummary: String?
        let record: Record?
    }
    let team: Team?
}

struct RosterDTO: Decodable {
    struct Athlete: Decodable {
        struct Position: Decodable { let displayName: String?; let abbreviation: String? }
        struct Experience: Decodable { let displayValue: String? }
        struct Flag: Decodable { let href: String?; let alt: String? }
        let id: String?
        let displayName: String?
        let jersey: String?
        let displayHeight: String?
        let age: Int?
        let experience: Experience?
        let position: Position?
        let flag: Flag?
        let citizenship: String?
        let items: [Athlete]?
    }
    struct Coach: Decodable { let firstName: String?; let lastName: String? }
    let athletes: [Athlete]?
    let coach: [Coach]?
}

struct ScheduleDTO: Decodable {
    struct Event: Decodable {
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
                    let logos: [Logo]?
                    let logo: String?
                }
                struct Score: Decodable {
                    struct Object: Decodable { let displayValue: String? }
                    let value: String?
                    init(from decoder: Decoder) throws {
                        let container = try decoder.singleValueContainer()
                        if let string = try? container.decode(String.self) {
                            value = string
                        } else if let object = try? container.decode(Object.self) {
                            value = object.displayValue
                        } else {
                            value = nil
                        }
                    }
                }
                let homeAway: String
                let score: Score?
                let winner: Bool?
                let team: Team
            }
            let status: Status
            let competitors: [Competitor]
        }
        let id: String
        let date: String
        let competitions: [Competition]
    }
    let events: [Event]?
}

extension TeamDetail {
    init?(info: TeamInfoDTO, roster: RosterDTO?, schedule: ScheduleDTO?, teamID: String) {
        guard let team = info.team else { return nil }
        let games = Self.games(schedule, teamID: teamID).sorted { $0.date < $1.date }
        let coach = roster?.coach?.first.flatMap { coach -> String? in
            let name = [coach.firstName, coach.lastName].compactMap { $0 }.joined(separator: " ")
            return name.isEmpty ? nil : name
        }
        self.init(
            id: team.id,
            name: team.displayName,
            logo: team.logos?.first.flatMap { URL(string: $0.href) },
            record: team.record?.items?.first?.summary,
            standing: team.standingSummary,
            coach: coach,
            roster: Self.players(roster),
            recent: Array(games.filter { $0.state == .final }.suffix(5).reversed()),
            upcoming: Array(games.filter { $0.state != .final }.prefix(5))
        )
    }

    private static func players(_ roster: RosterDTO?) -> [RosterPlayer] {
        let flat = (roster?.athletes ?? []).flatMap { $0.items ?? [$0] }
        return flat.compactMap { a in
            guard let id = a.id, let name = a.displayName else { return nil }
            return RosterPlayer(
                id: id,
                name: name,
                jersey: a.jersey,
                position: a.position?.displayName ?? a.position?.abbreviation ?? "Other",
                height: a.displayHeight,
                age: a.age,
                experience: a.experience?.displayValue,
                flag: a.flag?.href.flatMap(URL.init(string:)),
                country: a.citizenship ?? a.flag?.alt
            )
        }
    }

    private static func games(_ schedule: ScheduleDTO?, teamID: String) -> [TeamGame] {
        (schedule?.events ?? []).compactMap { event in
            guard
                let comp = event.competitions.first,
                let own = comp.competitors.first(where: { $0.team.id == teamID }),
                let other = comp.competitors.first(where: { $0.team.id != teamID }),
                let state = GameState(espn: comp.status.type.state),
                let date = ESPNDate.parse(event.date)
            else { return nil }
            let ownScore = own.score?.value
            let otherScore = other.score?.value
            let played = state != .upcoming && ownScore != nil && otherScore != nil
            var result: String?
            if state == .final, played {
                result = own.winner == true ? "W" : other.winner == true ? "L" : (Int(ownScore ?? "") == Int(otherScore ?? "") ? "D" : nil)
            }
            return TeamGame(
                eventID: event.id,
                date: date,
                isHome: own.homeAway == "home",
                opponent: other.team.displayName,
                opponentLogo: (other.team.logos?.first?.href ?? other.team.logo).flatMap(URL.init(string:)),
                state: state,
                statusText: comp.status.type.shortDetail,
                score: played ? "\(ownScore ?? "")–\(otherScore ?? "")" : nil,
                result: result
            )
        }
    }
}
