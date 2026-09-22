import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var store: EmailStore

    var body: some View {
        Group {
            if store.isMockMode || auth.isSignedIn {
                MainTabView()
            } else {
                SignInView()
            }
        }
        .onChange(of: auth.isSignedIn) { _, signedIn in
            if signedIn {
                Task { await store.loadInbox() }
            }
        }
    }
}
