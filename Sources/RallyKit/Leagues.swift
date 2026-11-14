import Foundation

public enum Sport: String, Sendable {
    case basketball, soccer, volleyball
}

public enum GroupID: String, CaseIterable, Sendable {
    case wnba, ncaaw, ncaav, nwsl, england, europe, national
}

public struct LeagueGroup: Sendable, Identifiable {
    public let id: GroupID
    public let label: String
    public let sport: Sport
    public let hue: String
    public let crowded: Bool
    public let teamSources: [String]
}

public struct League: Sendable, Identifiable {
    public let id: String
    public let name: String
    public let path: String
    public let group: GroupID
}

public enum Catalog {
    public static let groups: [LeagueGroup] = [
        LeagueGroup(id: .wnba, label: "WNBA", sport: .basketball, hue: "FF9A2E", crowded: false, teamSources: ["wnba"]),
        LeagueGroup(id: .ncaaw, label: "NCAA women's basketball", sport: .basketball, hue: "BBA7F0", crowded: true, teamSources: ["ncaaw"]),
        LeagueGroup(id: .ncaav, label: "NCAA volleyball", sport: .volleyball, hue: "F2545B", crowded: true, teamSources: ["ncaav"]),
        LeagueGroup(id: .nwsl, label: "NWSL", sport: .soccer, hue: "0EA66B", crowded: false, teamSources: ["nwsl"]),
        LeagueGroup(id: .england, label: "England", sport: .soccer, hue: "FF5AA5", crowded: false, teamSources: ["wsl"]),
        LeagueGroup(id: .europe, label: "Europe", sport: .soccer, hue: "4DB5FF", crowded: false, teamSources: ["uwcl", "liga-f", "premiere-ligue"]),
        LeagueGroup(id: .national, label: "National teams", sport: .soccer, hue: "3D5AFE", crowded: false, teamSources: ["world-cup", "euro", "nations-league", "friendlies"]),
    ]

    public static let leagues: [League] = [
        League(id: "wnba", name: "WNBA", path: "basketball/wnba", group: .wnba),
        League(id: "ncaaw", name: "NCAA women's basketball", path: "basketball/womens-college-basketball", group: .ncaaw),
        League(id: "ncaav", name: "NCAA women's volleyball", path: "volleyball/womens-college-volleyball", group: .ncaav),
        League(id: "nwsl", name: "NWSL", path: "soccer/usa.nwsl", group: .nwsl),
        League(id: "nwsl-cup", name: "NWSL Challenge Cup", path: "soccer/usa.nwsl.cup", group: .nwsl),
        League(id: "wsl", name: "Women's Super League", path: "soccer/eng.w.1", group: .england),
        League(id: "fa-cup", name: "Women's FA Cup", path: "soccer/eng.w.fa", group: .england),
        League(id: "league-cup", name: "Women's League Cup", path: "soccer/eng.w.league_cup", group: .england),
        League(id: "uwcl", name: "UEFA Women's Champions League", path: "soccer/uefa.wchampions", group: .europe),
        League(id: "liga-f", name: "Liga F", path: "soccer/esp.w.1", group: .europe),
        League(id: "premiere-ligue", name: "Première Ligue", path: "soccer/fra.w.1", group: .europe),
        League(id: "friendlies", name: "International friendlies", path: "soccer/fifa.friendly.w", group: .national),
        League(id: "world-cup", name: "Women's World Cup", path: "soccer/fifa.wwc", group: .national),
        League(id: "euro", name: "Women's Euro", path: "soccer/uefa.weuro", group: .national),
        League(id: "nations-league", name: "Women's Nations League", path: "soccer/uefa.w.nations", group: .national),
        League(id: "gold-cup", name: "Concacaf W Gold Cup", path: "soccer/concacaf.w.gold", group: .national),
        League(id: "w-championship", name: "Concacaf W Championship", path: "soccer/concacaf.womens.championship", group: .national),
        League(id: "asian-cup", name: "AFC Women's Asian Cup", path: "soccer/afc.w.asian.cup", group: .national),
        League(id: "africa-cup", name: "Women's Africa Cup of Nations", path: "soccer/caf.w.nations", group: .national),
        League(id: "olympics", name: "Olympic women's soccer", path: "soccer/fifa.w.olympics", group: .national),
    ]

    public static func group(_ id: GroupID) -> LeagueGroup {
        groups.first { $0.id == id }!
    }

    public static func league(_ id: String) -> League? {
        leagues.first { $0.id == id }
    }
}
