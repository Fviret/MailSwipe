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

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(store)
        }
        .onChange(of: scenePhase) { _, phase in
            // On ne laisse pas une action en attente se perdre si l'app quitte l'écran.
            if phase == .active {
                store.resurfaceDueSnoozes()
            } else {
                Task { await store.flushPending() }
            }
        }
    }
}
