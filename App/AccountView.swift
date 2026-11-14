import SwiftUI

struct AccountView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(FollowStore.self) private var follows
    @State private var email = ""
    @State private var code = ""
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    Text("Account").font(Theme.display(88))
                    Text(auth.isAvailable
                         ? "Sign in to keep your teams on every device. You don't need an account to use Rally."
                         : "You don't need an account to use Rally.")
                        .font(.subheadline)
                    if !auth.isAvailable {
                        Text("Accounts aren't turned on in this version yet. Your teams are saved on this phone.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.soft)
                    } else if auth.isSignedIn {
                        signedIn
                    } else if auth.pendingEmail != nil {
                        codeEntry
                    } else {
                        emailEntry
                    }
                    if let message = auth.message {
                        Text(message).font(.subheadline.weight(.semibold)).foregroundStyle(Color(hex: "B3261E"))
                    }
                    teamsSummary
                    about
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar(.hidden, for: .navigationBar)
            .background(Theme.chalk.ignoresSafeArea())
            .foregroundStyle(Theme.ink)
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(Theme.display(34))
            .padding(.top, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) { Rectangle().fill(Theme.ink).frame(height: 2) }
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .overlay(Rectangle().stroke(Theme.ink, lineWidth: 2))
    }

    private func solidButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.chalk)
                .padding(.horizontal, 24)
                .frame(minHeight: 48)
                .background(Theme.ink)
        }
        .disabled(auth.isBusy)
        .opacity(auth.isBusy ? 0.6 : 1)
    }

    private func ghostButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 24)
                .frame(minHeight: 48)
                .overlay(Rectangle().stroke(Theme.ink, lineWidth: 2))
        }
    }

    private var emailEntry: some View {
        VStack(alignment: .leading, spacing: 12) {
            label("Sync your teams")
            Text("Enter your email and we'll send you a 6-digit code. No password.").font(.subheadline)
            field("you@example.com", text: $email).keyboardType(.emailAddress).textContentType(.emailAddress)
            solidButton("Email me a code") {
                Task { await auth.sendCode(to: email.trimmingCharacters(in: .whitespaces)) }
            }
        }
    }

    private var codeEntry: some View {
        VStack(alignment: .leading, spacing: 12) {
            label("Enter your code")
            Text("We sent a 6-digit code to \(auth.pendingEmail ?? "your email").").font(.subheadline)
            field("123456", text: $code).keyboardType(.numberPad).textContentType(.oneTimeCode)
            HStack(spacing: 12) {
                solidButton("Sign in") { Task { await auth.verify(code: code.trimmingCharacters(in: .whitespaces)) } }
                ghostButton("Use a different email") { code = ""; auth.cancelCode() }
            }
        }
    }

    private var signedIn: some View {
        VStack(alignment: .leading, spacing: 12) {
            label("Signed in")
            Text("Signed in as \(auth.userEmail ?? ""). Your teams sync across your devices.").font(.subheadline)
            if let error = follows.syncError {
                Text(error).font(.subheadline.weight(.semibold)).foregroundStyle(Color(hex: "B3261E"))
            }
            HStack(spacing: 12) {
                ghostButton("Sign out") { Task { await auth.signOut() } }
                ghostButton("Delete account") { confirmingDelete = true }
            }
        }
        .confirmationDialog("Delete your account?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete account and followed teams", role: .destructive) { Task { await auth.deleteAccount() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes your account and the teams synced to it. Teams saved on this phone stay.")
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("About Rally")
            Text("Rally never shows betting odds, links to betting sites, or gambling advertising. Scores and schedules come from ESPN, and times are Eastern.")
                .font(.subheadline)
            HStack(spacing: 20) {
                Link("Privacy policy", destination: SiteLinks.privacy)
                Link("Terms", destination: SiteLinks.terms)
                Link("Support", destination: SiteLinks.support)
            }
            .font(.subheadline.weight(.bold))
            .padding(.top, 4)
        }
    }

    private var teamsSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Your teams")
            let count = follows.keys.count
            Text(count == 0
                 ? "You aren't following any teams yet."
                 : "\(count) \(count == 1 ? "team" : "teams") followed\(auth.isSignedIn ? ", synced to your account" : ", saved on this phone").")
                .font(.subheadline)
        }
    }
}
