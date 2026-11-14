import SwiftUI
import RallyKit

struct GameTile: View {
    let game: Game

    private var group: LeagueGroup {
        Catalog.group(Catalog.league(game.leagueID)!.group)
    }

    private var isLive: Bool { game.state == .live }
    private var background: Color { isLive ? Theme.ink : game.state == .final ? Theme.chalk : Color(hex: group.hue) }
    private var foreground: Color { isLive ? Theme.chalk : Theme.ink }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(Catalog.league(game.leagueID)?.name ?? "")
                    .font(.footnote.weight(.semibold))
                Spacer()
                status
            }
            VStack(spacing: 8) {
                teamRow(game.away)
                teamRow(game.home)
            }
            Text("\(EasternTime.clock(game.startsAt))\(game.venue.map { " · \($0)" } ?? "")")
                .font(.caption)
        }
        .padding(16)
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .overlay(
            Rectangle().stroke(isLive ? Theme.ink : Color(hex: group.hue), lineWidth: 2)
        )
    }

    @ViewBuilder
    private var status: some View {
        if isLive {
            Text(game.statusText)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Theme.lemon)
                .foregroundStyle(Theme.ink)
        } else {
            Text(game.state == .final ? "Final" : "Upcoming")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .overlay(Rectangle().stroke(foreground, lineWidth: 1.5))
        }
    }

    private func teamRow(_ side: Side) -> some View {
        HStack(spacing: 10) {
            AsyncImage(url: side.logo) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Text(side.abbreviation).font(.system(size: 10, weight: .bold))
            }
            .frame(width: 32, height: 32)
            .background(Circle().fill(Theme.chalk))
            .clipShape(Circle())
            HStack(spacing: 6) {
                if let rank = side.rank {
                    Text("\(rank)")
                        .font(.caption2.weight(.heavy))
                        .padding(.horizontal, 4)
                        .overlay(Rectangle().stroke(foreground, lineWidth: 1.5))
                }
                Text(side.name).font(.headline).lineLimit(2)
            }
            Spacer()
            Text(game.state == .upcoming ? "" : "\(side.score ?? 0)")
                .font(Theme.display(52))
                .monospacedDigit()
        }
    }
}
