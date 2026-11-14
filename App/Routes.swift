import SwiftUI
import RallyKit

struct TeamRoute: Hashable {
    let leagueID: String
    let teamID: String
}

extension View {
    func rallyDestinations() -> some View {
        navigationDestination(for: Game.self) { GameDetailView(leagueID: $0.leagueID, eventID: $0.eventID) }
            .navigationDestination(for: GameRoute.self) { GameDetailView(leagueID: $0.leagueID, eventID: $0.eventID) }
            .navigationDestination(for: PlayerRoute.self) { PlayerView(leagueID: $0.leagueID, athleteID: $0.athleteID) }
            .navigationDestination(for: TeamRoute.self) { TeamView(leagueID: $0.leagueID, teamID: $0.teamID) }
    }
}
