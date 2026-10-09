import XCTest
@testable import MailSwipe

@MainActor
final class UndoTests: XCTestCase {
    private var spy: SpyMailService!
    private var store: EmailStore!

    override func setUp() async throws {
        spy = SpyMailService()
        store = EmailStore(auth: AuthManager(), mock: spy, undoDelay: 60, storageDirectory: TestStorage.makeDirectory())
        await store.loadInbox()
    }

    override func tearDown() async throws {
        store.undo()
    }

    private func serverCalls() -> [String] { spy.calls.filter { !$0.hasPrefix("fetchInbox") } }

    func testCardDisappearsButNothingIsSentDuringUndoWindow() {
        let card = store.inbox[0]
        store.delete(card)
        XCTAssertFalse(store.inbox.contains(card))
        XCTAssertNotNil(store.pending)
        XCTAssertTrue(serverCalls().isEmpty, "rien ne part au serveur avant la fin du délai")
    }

    func testUndoRestoresCardAtSamePositionAndSendsNothing() {
        let card = store.inbox[2]
        store.archive(card)
        store.undo()
        XCTAssertEqual(store.inbox[2], card)
        XCTAssertNil(store.pending)
        XCTAssertTrue(store.archived.isEmpty)
        XCTAssertTrue(serverCalls().isEmpty)
    }

    func testUndoReplyNeverSendsTheMail() async {
        let card = store.inbox[0]
        store.reply(card, text: "bonjour")
        store.undo()
        await store.flushPending()
        XCTAssertTrue(serverCalls().isEmpty)
    }

    func testFlushCommitsImmediately() async {
        let card = store.inbox[0]
        store.delete(card)
        await store.flushPending()
        XCTAssertEqual(serverCalls(), ["trash:\(card.id)"])
        XCTAssertNil(store.pending)
        XCTAssertFalse(store.inbox.contains(card))
    }

    func testStartingANewActionCommitsThePreviousOne() async {
        let first = store.inbox[0], second = store.inbox[1]
        store.delete(first)
        store.archive(second)
        try? await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(serverCalls().first, "trash:\(first.id)")
        XCTAssertEqual(store.pending?.card, second)
    }

    func testCommitIsIdempotent() async {
        let card = store.inbox[0]
        store.delete(card)
        await store.flushPending()
        await store.flushPending()
        XCTAssertEqual(serverCalls().count, 1)
    }

    func testArchiveAppearsInArchiveOnlyAfterCommit() async {
        let card = store.inbox[0]
        store.archive(card)
        XCTAssertTrue(store.archived.isEmpty)
        await store.flushPending()
        XCTAssertEqual(store.archived.first, card)
    }
}

@MainActor
final class SnoozeResurfaceTests: XCTestCase {
    func testDueSnoozedMailReturnsToTopOfInboxAndIsRestoredInGmail() async {
        let spy = SpyMailService()
        let store = EmailStore(auth: AuthManager(), mock: spy, undoDelay: 0, storageDirectory: TestStorage.makeDirectory())
        await store.loadInbox()
        let card = store.inbox[3]
        await store.snooze(card, duration: .oneHour).value
        XCTAssertFalse(store.inbox.contains(card))

        store.snoozeScheduler.snooze(card, until: Date().addingTimeInterval(-1)) // l'heure est passée
        store.resurfaceDueSnoozes()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(store.inbox.first, card)
        XCTAssertTrue(spy.calls.contains("unsnooze:\(card.id)"))
        XCTAssertTrue(store.snoozeScheduler.items.isEmpty)
    }

    func testReloadDoesNotSwallowAMailThatBecameDue() async {
        let spy = SpyMailService()
        let store = EmailStore(auth: AuthManager(), mock: spy, undoDelay: 0, storageDirectory: TestStorage.makeDirectory())
        await store.loadInbox()
        let card = store.inbox[0]
        await store.snooze(card, duration: .oneHour).value
        store.snoozeScheduler.snooze(card, until: Date().addingTimeInterval(-1))
        await store.loadInbox(force: true)
        XCTAssertEqual(store.inbox.first, card)
    }
}
