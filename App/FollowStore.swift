import Foundation
import Observation
import RallyKit
import Supabase

private struct FollowRow: Codable {
    let team_key: String
}

@MainActor
@Observable
final class FollowStore {
    private static let storageKey = "rally-follow"
    private(set) var keys: Set<String>
    private(set) var syncError: String?
    private let client: SupabaseClient?
    private var isSignedIn = false

    init(client: SupabaseClient?) {
        self.client = client
        let stored = UserDefaults.standard.stringArray(forKey: Self.storageKey) ?? []
        keys = Set(stored)
    }

    func isFollowing(_ key: String) -> Bool { keys.contains(key) }

    func isPinned(_ game: Game) -> Bool {
        FollowKey.keys(for: game).contains { keys.contains($0) }
    }

    func toggle(_ key: String) {
        let adding = !keys.contains(key)
        if adding { keys.insert(key) } else { keys.remove(key) }
        persist()
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

    private func persist() {
        UserDefaults.standard.set(Array(keys), forKey: Self.storageKey)
    }
}
