import SwiftUI
import RallyKit

struct TonightView: View {
    @State private var model = TonightViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    header
                    ForEach(model.featured) { game in
                        GameTile(game: game)
                    }
                    if !model.more.isEmpty {
                        DisclosureGroup("All other college games (\(model.more.count))") {
                            ForEach(model.more) { game in
                                moreRow(game)
                            }
                        }
                        .font(.headline)
                        .padding(.top, 8)
                    }
                }
                .padding(16)
            }
            .background(Theme.chalk)
            .foregroundStyle(Theme.ink)
            .refreshable { await model.load() }
            .task { await model.load() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tonight").font(Theme.display(88))
            Text("\(model.games.count) games. \(model.liveCount) live now. All times Eastern.")
                .font(.subheadline)
        }
    }

    private func moreRow(_ game: Game) -> some View {
        HStack {
            Text(EasternTime.clock(game.startsAt)).font(.subheadline.weight(.semibold)).monospacedDigit()
            Text("\(game.away.name) at \(game.home.name)").font(.subheadline).lineLimit(1)
            Spacer()
            if game.state != .upcoming {
                Text("\(game.away.score ?? 0)–\(game.home.score ?? 0)").font(.subheadline.weight(.bold)).monospacedDigit()
            }
        }
        .padding(.vertical, 6)
    }
}
