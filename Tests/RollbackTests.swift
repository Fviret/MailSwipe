import XCTest
@testable import MailSwipe

@MainActor
final class RollbackTests: XCTestCase {
    private var spy: SpyMailService!
    private var store: EmailStore!

    override func setUp() async throws {
        spy = SpyMailService()
        store = EmailStore(auth: AuthManager(), mock: spy, undoDelay: 0, storageDirectory: TestStorage.makeDirectory())
        await store.loadInbox()
    }

    override func tearDown() async throws {
    }

    func testDeleteFailureRestoresCardAtSamePosition() async {
        let card = store.inbox[2]
        spy.failing = true
        await store.delete(card).value
        XCTAssertEqual(store.inbox[2], card)
        XCTAssertEqual(store.errorMessage, String(localized: "Échec de la suppression : \("boom")"))
    }

    func testArchiveFailureRestoresCardAndClearsArchive() async {
        let card = store.inbox[0]
        spy.failing = true
        await store.archive(card).value
        XCTAssertEqual(store.inbox.first, card)
        XCTAssertTrue(store.archived.isEmpty)
    }

    func testReplyFailureRestoresCard() async {
        let card = store.inbox[1]
        spy.failing = true
        await store.reply(card, text: "ok").value
        XCTAssertEqual(store.inbox[1], card)
        XCTAssertNotNil(store.errorMessage)
    }

    func testSnoozeFailureCancelsLocalSnooze() async {
        let card = store.inbox[0]
        spy.failing = true
        await store.snooze(card, duration: .oneHour).value
        XCTAssertEqual(store.inbox.first, card)
        XCTAssertTrue(store.snoozeScheduler.items.isEmpty)
    }

    func testSuccessKeepsCardRemoved() async {
        let card = store.inbox[0]
        await store.delete(card).value
        XCTAssertFalse(store.inbox.contains(card))
        XCTAssertNil(store.errorMessage)
        XCTAssertEqual(spy.calls.last, "trash:\(card.id)")
    }

    func testNewActionClearsPreviousError() async {
        spy.failing = true
        await store.delete(store.inbox[0]).value
        XCTAssertNotNil(store.errorMessage)
        spy.failing = false
        await store.delete(store.inbox[0]).value
        XCTAssertNil(store.errorMessage)
    }
}
