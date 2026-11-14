import Foundation
import Supabase

enum SupabaseConfig {
    static func makeClient() -> SupabaseClient? {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
            let key = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String,
            !urlString.isEmpty, !key.isEmpty,
            let url = URL(string: urlString)
        else { return nil }
        return SupabaseClient(supabaseURL: url, supabaseKey: key)
    }
}
