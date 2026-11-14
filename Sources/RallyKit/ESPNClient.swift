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
}
