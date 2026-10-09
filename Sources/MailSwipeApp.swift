import SwiftUI

@main
struct MailSwipeApp: App {
    @StateObject private var auth: AuthManager
    @StateObject private var store: EmailStore

    init() {
        if LaunchOptions.isUITesting {
            let authManager = AuthManager(refreshTokenKey: "ui-testing-refresh-token")
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("mailswipe-ui-\(UUID().uuidString)", isDirectory: true)
            _auth = StateObject(wrappedValue: authManager)
            _store = StateObject(wrappedValue: EmailStore(
                auth: authManager,
                undoDelay: LaunchOptions.undoDelay,
                storageDirectory: directory,
                gmailConfigured: LaunchOptions.simulatesGmailConfigured,
                notifications: NoopNotificationScheduler()
            ))
        } else {
            let authManager = AuthManager()
            _auth = StateObject(wrappedValue: authManager)
            _store = StateObject(wrappedValue: EmailStore(auth: authManager))
        }
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
