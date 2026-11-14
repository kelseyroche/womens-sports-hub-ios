import SwiftUI
import RallyKit

struct CompactRow: View {
    let game: Game
    var pinned = false

    private var hue: Color {
        Color(hex: Catalog.group(Catalog.league(game.leagueID)!.group).hue)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle().fill(hue).frame(width: 6)
            Text(EasternTime.clock(game.startsAt))
                .font(.callout.weight(.heavy))
                .monospacedDigit()
                .frame(width: 84, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(game.away.name) at \(game.home.name)")
                    .font(.subheadline.weight(.semibold))
                Text("\(Catalog.league(game.leagueID)?.name ?? "")\(pinned ? " · Your team" : "")")
                    .font(.caption)
                    .foregroundStyle(Theme.soft)
            }
            Spacer(minLength: 8)
            if game.state != .upcoming {
                Text("\(game.away.score ?? 0)–\(game.home.score ?? 0)")
                    .font(.subheadline.weight(.heavy))
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 8)
        .overlay(alignment: .top) { Rectangle().fill(Theme.rule).frame(height: 1) }
    }
}
