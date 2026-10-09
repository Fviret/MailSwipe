import XCTest
@testable import MailSwipe

@MainActor
final class PaginationTests: XCTestCase {
    private var spy: SpyMailService!
    private var store: EmailStore!

    override func setUp() async throws {
        spy = SpyMailService()
        spy.pageSize = 4
        store = EmailStore(auth: AuthManager(), mock: spy)
        await store.loadInbox()
    }

    func testFirstPageOnly() {
        XCTAssertEqual(store.inbox.count, 4)
        XCTAssertTrue(store.hasMore)
    }

    func testNoPrefetchWhileEnoughCardsRemain() async {
        let big = SpyMailService()
        big.pageSize = 8
        let bigStore = EmailStore(auth: AuthManager(), mock: big)
        await bigStore.loadInbox()
        await bigStore.loadMoreIfNeeded()
        XCTAssertEqual(bigStore.inbox.count, 8)
        XCTAssertEqual(big.calls.filter { $0.hasPrefix("fetchInbox") }.count, 1, "8 cartes > seuil 5 : aucune requête de plus")
    }

    func testPrefetchLoadsNextPageWhenRunningLow() async {
        await store.loadMoreIfNeeded()
        XCTAssertEqual(store.inbox.count, 8)
        XCTAssertTrue(store.hasMore)
    }

    func testLastPageClearsHasMore() async {
        await store.loadMoreIfNeeded() // 8
        store.delete(store.inbox[0]); store.delete(store.inbox[0]); store.delete(store.inbox[0]) // 5
        await store.loadMoreIfNeeded() // +4 = 9 -> total 12 loaded
        XCTAssertFalse(store.hasMore)
        XCTAssertEqual(store.inbox.count + 3, MockData.inbox().count)
    }

    func testHandledMailsAreNotReintroduced() async {
        let first = store.inbox[0]
        await store.delete(first).value
        spy.cards.insert(first, at: 4) // Gmail renvoie encore le mail supprimé sur la page suivante
        await store.loadMoreIfNeeded()
        XCTAssertFalse(store.inbox.contains(first))
    }

    func testFailedLoadMoreKeepsCardsAndReportsError() async {
        spy.failing = true
        await store.loadMoreIfNeeded()
        XCTAssertEqual(store.inbox.count, 4)
        XCTAssertNotNil(store.errorMessage)
    }

    func testNoEmptyStateWhileMoreMailsExist() async {
        for card in store.inbox { await store.delete(card).value }
        XCTAssertTrue(store.inbox.isEmpty)
        XCTAssertTrue(store.hasMore, "la vue doit charger la suite plutôt qu'afficher « Boîte vide »")
    }
}
