import Foundation
import Observation
import RallyKit
import Supabase

private struct FollowRow: Codable {
    let team_key: String
}

struct FollowedTeam: Codable, Identifiable, Hashable {
    let key: String
    let teamID: String
    let leagueID: String
    let name: String
    let logo: URL?
    var id: String { key }
}

@MainActor
@Observable
final class FollowStore {
    private static let storageKey = "rally-follow"
    private static let metaKey = "rally-follow-meta"
    private(set) var keys: Set<String>
    private(set) var meta: [String: FollowedTeam]
    private(set) var syncError: String?
    private let client: SupabaseClient?
    private var isSignedIn = false

    init(client: SupabaseClient?) {
        self.client = client
        let stored = UserDefaults.standard.stringArray(forKey: Self.storageKey) ?? []
        keys = Set(stored)
        if let data = UserDefaults.standard.data(forKey: Self.metaKey),
           let decoded = try? JSONDecoder().decode([String: FollowedTeam].self, from: data) {
            meta = decoded
        } else {
            meta = [:]
        }
    }

    var followedTeams: [FollowedTeam] {
        keys.compactMap { meta[$0] }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func resolveMissing() async {
        let missing = keys.filter { meta[$0] == nil }
        guard !missing.isEmpty else { return }
        let client = ESPNClient()
        for group in Catalog.groups {
            let wanted = missing.filter { $0.hasPrefix("\(group.sport.rawValue):") && meta[$0] == nil }
            guard !wanted.isEmpty else { continue }
            let teams = await client.teams(in: group)
            for team in teams {
                let key = FollowKey.make(sport: group.sport, teamID: team.id)
                if wanted.contains(key), meta[key] == nil {
                    meta[key] = FollowedTeam(key: key, teamID: team.id, leagueID: team.leagueID, name: team.name, logo: team.logo)
                }
            }
        }
        saveMeta()
    }

    func isFollowing(_ key: String) -> Bool { keys.contains(key) }

    func isPinned(_ game: Game) -> Bool {
        FollowKey.keys(for: game).contains { keys.contains($0) }
    }

    func toggle(_ key: String, team: FollowedTeam? = nil) {
        let adding = !keys.contains(key)
        if adding {
            keys.insert(key)
            if let team { meta[key] = team }
        } else {
            keys.remove(key)
            meta[key] = nil
        }
        persist()
        saveMeta()
        guard isSignedIn, let client else { return }
        Task {
            do {
                if adding {
                    try await client.from("follows")
                        .upsert(FollowRow(team_key: key), onConflict: "user_id,team_key", ignoreDuplicates: true)
                        .execute()
                } else {
                    try await client.from("follows").delete().eq("team_key", value: key).execute()
                }
                syncError = nil
            } catch {
                syncError = "Couldn't sync that change. It's saved on this phone."
            }
        }
    }

    func setSignedIn(_ signedIn: Bool) async {
        isSignedIn = signedIn
        guard signedIn, let client else {
            syncError = nil
            return
        }
        do {
            let remote: [FollowRow] = try await client.from("follows").select("team_key").execute().value
            let remoteKeys = Set(remote.map(\.team_key))
            let missing = keys.subtracting(remoteKeys)
            if !missing.isEmpty {
                try await client.from("follows")
                    .upsert(missing.map { FollowRow(team_key: $0) }, onConflict: "user_id,team_key", ignoreDuplicates: true)
                    .execute()
            }
            keys.formUnion(remoteKeys)
            persist()
            syncError = nil
        } catch {
            #if DEBUG
            syncError = "DEBUG: \(error)"
            #else
            syncError = "Couldn't sync your teams. They're saved on this phone."
            #endif
        }
    }

    private func saveMeta() {
        if let data = try? JSONEncoder().encode(meta) {
            UserDefaults.standard.set(data, forKey: Self.metaKey)
        }
    }

    private func persist() {
        UserDefaults.standard.set(Array(keys), forKey: Self.storageKey)
    }
}
