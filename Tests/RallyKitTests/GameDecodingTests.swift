import XCTest
@testable import RallyKit

final class GameDecodingTests: XCTestCase {
    func testDecodesLiveGame() throws {
        let json = """
        {"events":[{"id":"1","date":"2026-11-14T00:00Z","status":{"type":{"state":"in","shortDetail":"3rd Set"}},
        "competitions":[{"venue":{"fullName":"Arena"},"competitors":[
        {"homeAway":"home","score":"2","curatedRank":{"current":9},"team":{"id":"10","displayName":"Home Team","abbreviation":"HOM","logo":"https://example.com/h.png"}},
        {"homeAway":"away","score":"1","curatedRank":{"current":99},"team":{"id":"20","displayName":"Away Team"}}]}]}]}
        """
        let board = try JSONDecoder().decode(ScoreboardDTO.self, from: Data(json.utf8))
        let league = try XCTUnwrap(Catalog.league("ncaav"))
        let game = try XCTUnwrap(Game(league: league, event: try XCTUnwrap(board.events?.first)))
        XCTAssertEqual(game.state, .live)
        XCTAssertEqual(game.home.score, 2)
        XCTAssertEqual(game.home.rank, 9)
        XCTAssertNil(game.away.rank)
        XCTAssertEqual(game.away.abbreviation, "AWA")
        XCTAssertEqual(game.id, "ncaav-1")
    }

    func testUpcomingGameHidesScore() throws {
        let json = """
        {"events":[{"id":"2","date":"2026-11-14T18:00Z","status":{"type":{"state":"pre","shortDetail":"1:00 PM"}},
        "competitions":[{"competitors":[
        {"homeAway":"home","score":"0","team":{"id":"1","displayName":"A"}},
        {"homeAway":"away","score":"0","team":{"id":"2","displayName":"B"}}]}]}]}
        """
        let board = try JSONDecoder().decode(ScoreboardDTO.self, from: Data(json.utf8))
        let league = try XCTUnwrap(Catalog.league("wnba"))
        let game = try XCTUnwrap(Game(league: league, event: try XCTUnwrap(board.events?.first)))
        XCTAssertEqual(game.state, .upcoming)
        XCTAssertNil(game.home.score)
    }
}
