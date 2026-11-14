import Foundation

public struct Team: Sendable, Identifiable {
    public let id: String
    public let name: String
    public let abbreviation: String
    public let logo: URL?
    public let rank: Int?
    public let popular: Bool
    public let leagueID: String
}

struct TeamsDTO: Decodable {
    struct Sport: Decodable {
        struct League: Decodable {
            struct Entry: Decodable {
                struct Logo: Decodable { let href: String }
                struct Info: Decodable {
                    let id: String
                    let displayName: String
                    let abbreviation: String?
                    let logos: [Logo]?
                }
                let team: Info
            }
            let teams: [Entry]?
        }
        let leagues: [League]?
    }
    let sports: [Sport]?
}

struct RankingsDTO: Decodable {
    struct Poll: Decodable {
        struct Rank: Decodable {
            struct Ref: Decodable { let id: String }
            let current: Int
            let team: Ref
        }
        let ranks: [Rank]?
    }
    let rankings: [Poll]?
}
