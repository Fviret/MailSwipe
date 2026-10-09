import XCTest
@testable import MailSwipe

final class JSONFileStoreTests: XCTestCase {
    private var dir: URL!
    override func setUp() { dir = TestStorage.makeDirectory() }

    func testRoundTrip() {
        let store = JSONFileStore<[EmailCard]>(filename: "a.json", directory: dir)
        let cards = Array(MockData.inbox().prefix(3))
        store.save(cards)
        XCTAssertEqual(store.load(), cards)
        XCTAssertEqual(store.load()?.first?.subject, cards[0].subject)
    }

    func testMissingFileLoadsNil() {
        XCTAssertNil(JSONFileStore<[EmailCard]>(filename: "none.json", directory: dir).load())
    }

    func testCorruptedFileLoadsNilInsteadOfCrashing() throws {
        let store = JSONFileStore<[EmailCard]>(filename: "bad.json", directory: dir)
        try Data("pas du json".utf8).write(to: store.url)
        XCTAssertNil(store.load())
    }

    func testDeleteRemovesFile() {
        let store = JSONFileStore<[EmailCard]>(filename: "d.json", directory: dir)
        store.save(MockData.inbox())
        store.delete()
        XCTAssertNil(store.load())
    }

    func testDirectoryIsExcludedFromBackup() throws {
        _ = JSONFileStore<Int>(filename: "x.json", directory: dir)
        XCTAssertEqual(try dir.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
    }
}

@MainActor
final class LocalDataTests: XCTestCase {
    func testArchiveSurvivesRestart() async {
        let dir = TestStorage.makeDirectory()
        let first = EmailStore(auth: AuthManager(), undoDelay: 0, storageDirectory: dir)
        await first.loadInbox()
        let card = first.inbox[0]
        await first.archive(card).value

        let second = EmailStore(auth: AuthManager(), undoDelay: 0, storageDirectory: dir)
        XCTAssertEqual(second.archived.first, card)
    }

    func testSnoozeSurvivesRestart() async {
        let dir = TestStorage.makeDirectory()
        let first = EmailStore(auth: AuthManager(), undoDelay: 0, storageDirectory: dir)
        await first.loadInbox()
        let card = first.inbox[0]
        await first.snooze(card, duration: .nextWeek).value

        let second = EmailStore(auth: AuthManager(), undoDelay: 0, storageDirectory: dir)
        XCTAssertEqual(second.snoozeScheduler.items.first?.card, card)
    }

    func testClearLocalDataWipesArchiveAndSnoozeOnDisk() async {
        let dir = TestStorage.makeDirectory()
        let store = EmailStore(auth: AuthManager(), undoDelay: 0, storageDirectory: dir)
        await store.loadInbox()
        await store.archive(store.inbox[0]).value
        await store.snooze(store.inbox[0], duration: .nextWeek).value
        store.clearLocalData()

        let reopened = EmailStore(auth: AuthManager(), undoDelay: 0, storageDirectory: dir)
        XCTAssertTrue(reopened.archived.isEmpty)
        XCTAssertTrue(reopened.snoozeScheduler.items.isEmpty)
    }

    func testArchiveIsCapped() {
        let dir = TestStorage.makeDirectory()
        let store = EmailStore(auth: AuthManager(), undoDelay: 0, storageDirectory: dir)
        let card = MockData.inbox()[0]
        store.archived = (0..<(EmailStore.archiveLimit + 25)).map {
            var c = card; c = EmailCard(id: "id-\($0)", threadId: c.threadId, subject: c.subject, snippet: c.snippet, senderName: c.senderName, senderEmail: c.senderEmail, date: c.date, isUnread: c.isUnread); return c
        }
        let reopened = EmailStore(auth: AuthManager(), undoDelay: 0, storageDirectory: dir)
        XCTAssertEqual(reopened.archived.count, EmailStore.archiveLimit)
    }

    func testNoUserDefaultsLeftForMailContent() {
        XCTAssertNil(UserDefaults.standard.data(forKey: "mailswipe.snoozed"))
    }
}
