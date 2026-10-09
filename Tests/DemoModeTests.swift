import XCTest
@testable import MailSwipe

@MainActor
final class DemoModeTests: XCTestCase {
    private func makeStore(configured: Bool, live: SpyMailService? = nil, demo: SpyMailService = SpyMailService(), dir: URL = TestStorage.makeDirectory()) -> (EmailStore, AuthManager) {
        let auth = AuthManager()
        let store = EmailStore(auth: auth, gmail: live, mock: demo, undoDelay: 0, storageDirectory: dir, gmailConfigured: configured, notifications: RecordingNotifications())
        return (store, auth)
    }

    func testUnconfiguredBuildIsAlwaysInDemo() {
        let (store, _) = makeStore(configured: false)
        XCTAssertTrue(store.isMockMode)
        store.exitMockPreview()
        XCTAssertTrue(store.isMockMode, "sans Client ID il n'y a pas d'autre mode")
    }

    func testConfiguredBuildStartsInLiveMode() {
        let (store, _) = makeStore(configured: true, live: SpyMailService())
        XCTAssertFalse(store.isMockMode)
    }

    func testEnteringDemoDoesNotTouchTheRealAccount() async {
        let live = SpyMailService()
        let (store, auth) = makeStore(configured: true, live: live)
        auth.isSignedIn = true
        store.enableMockPreview()
        await store.loadInbox()
        XCTAssertTrue(live.calls.isEmpty, "le mode démo ne doit faire aucun appel au service Gmail")
        XCTAssertFalse(store.inbox.isEmpty)
    }

    func testDemoArchiveIsInvisibleInRealModeAndSurvivesReEntering() async {
        let (store, auth) = makeStore(configured: true, live: SpyMailService())
        auth.isSignedIn = true
        store.enableMockPreview()
        await store.loadInbox()
        let card = store.inbox[0]
        await store.archive(card).value
        XCTAssertEqual(store.archived.first, card)

        store.exitMockPreview()
        XCTAssertTrue(store.archived.isEmpty, "les archives de démo ne se mélangent pas au vrai compte")

        store.enableMockPreview()
        XCTAssertEqual(store.archived.first, card)
    }

    func testDemoSnoozeDoesNotLeakIntoRealAccount() async {
        let (store, auth) = makeStore(configured: true, live: SpyMailService())
        auth.isSignedIn = true
        store.enableMockPreview()
        await store.loadInbox()
        await store.snooze(store.inbox[0], duration: .nextWeek).value
        XCTAssertEqual(store.snoozeScheduler.items.count, 1)
        store.exitMockPreview()
        XCTAssertTrue(store.snoozeScheduler.items.isEmpty)
        store.snoozeScheduler.removeAll()
    }

    func testExitingDemoLoadsTheRealInbox() async {
        let live = SpyMailService()
        live.cards = [MockData.inbox()[3]]
        let (store, auth) = makeStore(configured: true, live: live)
        auth.isSignedIn = true
        store.enableMockPreview()
        await store.loadInbox()
        store.exitMockPreview()
        XCTAssertTrue(store.inbox.isEmpty, "la pile de démo ne reste pas affichée")
        await store.loadInbox()
        XCTAssertEqual(store.inbox, [MockData.inbox()[3]])
    }

    func testRealModeRequiresSignIn() async {
        let live = SpyMailService()
        let (store, _) = makeStore(configured: true, live: live)
        await store.loadInbox()
        XCTAssertTrue(live.calls.isEmpty)
        XCTAssertTrue(store.inbox.isEmpty)
    }
}
