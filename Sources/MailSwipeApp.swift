import SwiftUI

@main
struct MailSwipeApp: App {
    @StateObject private var auth: AuthManager
    @StateObject private var store: EmailStore

    init() {
        let authManager = AuthManager()
        _auth = StateObject(wrappedValue: authManager)
        _store = StateObject(wrappedValue: EmailStore(auth: authManager))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(store)
        }
    }
}
