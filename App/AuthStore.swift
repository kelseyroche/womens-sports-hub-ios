import Foundation
import Observation
import Supabase

@MainActor
@Observable
final class AuthStore {
    private(set) var userEmail: String?
    private(set) var pendingEmail: String?
    private(set) var message: String?
    private(set) var isBusy = false
    private let client: SupabaseClient?
    private let follows: FollowStore

    init(client: SupabaseClient?, follows: FollowStore) {
        self.client = client
        self.follows = follows
    }

    var isAvailable: Bool { client != nil }
    var isSignedIn: Bool { userEmail != nil }

    func start() async {
        guard let client else { return }
        await apply(try? await client.auth.session)
        #if DEBUG
        await runDebugSignIn(client)
        #endif
        for await (event, session) in client.auth.authStateChanges {
            if event == .signedOut {
                await apply(nil)
            } else if let session {
                await apply(session)
            }
        }
    }

    private func apply(_ session: Session?) async {
        userEmail = session?.user.email
        await follows.setSignedIn(session != nil)
    }

    func sendCode(to email: String) async {
        guard let client else { return }
        isBusy = true
        message = nil
        defer { isBusy = false }
        do {
            try await client.auth.signInWithOTP(email: email)
            pendingEmail = email
        } catch {
            message = "We couldn't send a code to that address. Check it and try again."
        }
    }

    func verify(code: String) async {
        guard let client, let email = pendingEmail else { return }
        isBusy = true
        message = nil
        defer { isBusy = false }
        do {
            let response = try await client.auth.verifyOTP(email: email, token: code, type: .email)
            pendingEmail = nil
            await apply(response.session)
        } catch {
            message = "That code didn't work. Check it, or ask for a new one."
        }
    }

    func cancelCode() {
        pendingEmail = nil
        message = nil
    }

    func signOut() async {
        guard let client else { return }
        try? await client.auth.signOut()
        await apply(nil)
    }

    func deleteAccount() async {
        guard let client else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await client.rpc("delete_my_account").execute()
            try? await client.auth.signOut()
            await apply(nil)
        } catch {
            message = "We couldn't delete your account. Try again."
        }
    }

    #if DEBUG
    private func runDebugSignIn(_ client: SupabaseClient) async {
        let defaults = UserDefaults.standard
        guard let email = defaults.string(forKey: "rally-test-email") else { return }
        if let code = defaults.string(forKey: "rally-test-code") {
            pendingEmail = email
            await verify(code: code)
        } else {
            await sendCode(to: email)
        }
    }
    #endif
}
