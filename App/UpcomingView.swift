import SwiftUI
import RallyKit

struct UpcomingDay: Identifiable {
    let id: String
    let date: Date
    let games: [Game]
}

@MainActor
@Observable
final class UpcomingViewModel {
    private(set) var days: [UpcomingDay] = []
    private(set) var isLoading = false
    private let client = ESPNClient()

    func load() async {
        isLoading = true
        let now = Date()
        let loaded = await withTaskGroup(of: (Int, UpcomingDay).self) { group in
            for offset in 1...7 {
                group.addTask {
                    let date = EasternTime.addingDays(offset, to: now)
                    let games = await self.client.games(on: EasternTime.day(date))
                    return (offset, UpcomingDay(id: EasternTime.day(date), date: date, games: games))
                }
            }
            var all: [(Int, UpcomingDay)] = []
            for await item in group { all.append(item) }
            return all.sorted { $0.0 < $1.0 }.map(\.1)
        }
        days = loaded
        isLoading = false
    }
}

struct UpcomingView: View {
    @State private var model = UpcomingViewModel()
    @Environment(FollowStore.self) private var follows

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    Text("Upcoming").font(Theme.display(88))
                    if !model.days.isEmpty {
                        let total = model.days.reduce(0) { $0 + $1.games.count }
                        Text("\(total) games over the next 7 days. Games with your teams come first each day. All times Eastern.")
                            .font(.subheadline)
                    }
                    ForEach(model.days) { day in
                        section(day)
                    }
                }
                .padding(16)
            }
            .toolbar(.hidden, for: .navigationBar)
            .rallyDestinations()
            .background(Theme.chalk.ignoresSafeArea())
            .foregroundStyle(Theme.ink)
            .overlay {
                if model.isLoading && model.days.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading the week").font(.subheadline)
                    }
                }
            }
            .refreshable { await model.load() }
            .task { await model.load() }
        }
    }

    private func section(_ day: UpcomingDay) -> some View {
        let pinned = day.games.filter { follows.isPinned($0) }
        let split = Featuring.split(day.games.filter { !follows.isPinned($0) })
        return VStack(alignment: .leading, spacing: 0) {
            Text(EasternTime.heading(day.date, relativeTo: Date()))
                .font(Theme.display(34))
                .padding(.top, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .top) { Rectangle().fill(Theme.ink).frame(height: 2) }
            if day.games.isEmpty {
                Text("No games scheduled.").font(.subheadline).foregroundStyle(Theme.soft).padding(.top, 8)
            }
            ForEach(pinned) { CompactRow(game: $0, pinned: true) }
            ForEach(split.featured) { CompactRow(game: $0) }
            if !split.more.isEmpty {
                DisclosureGroup("All other college games (\(split.more.count))") {
                    ForEach(split.more) { CompactRow(game: $0) }
                }
                .font(.headline)
                .padding(.top, 8)
            }
        }
    }
}
