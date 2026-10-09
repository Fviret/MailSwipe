import XCTest
@testable import MailSwipe

@MainActor
final class EmailStoreTests: XCTestCase {
    private func makeStore() -> EmailStore {
        EmailStore(auth: AuthManager())
    }

    func testLoadInboxFillsFromMockService() async {
        let store = makeStore()
        await store.loadInbox()
        XCTAssertEqual(store.inbox.count, MockMailService.defaultPageSize)
    }

    func testLoadInboxDoesNotResetAfterSwipes() async {
        let store = makeStore()
        await store.loadInbox()
        let first = store.inbox[0]
        store.delete(first)
        await store.loadInbox()
        XCTAssertFalse(store.inbox.contains(first), "un rechargement implicite ne doit pas ressusciter un mail traité")
    }

    func testForcedReloadRestoresInbox() async {
        let store = makeStore()
        await store.loadInbox()
        store.delete(store.inbox[0])
        await store.loadInbox(force: true)
        XCTAssertEqual(store.inbox.count, MockMailService.defaultPageSize)
    }

    func testArchiveMovesCardToArchive() async {
        let store = makeStore()
        await store.loadInbox()
        let card = store.inbox[0]
        store.archive(card)
        XCTAssertFalse(store.inbox.contains(card))
        XCTAssertEqual(store.archived.first, card)
    }
}
