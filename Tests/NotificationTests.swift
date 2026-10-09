import XCTest
@testable import MailSwipe

@MainActor
final class NotificationTests: XCTestCase {
    private func makeScheduler(_ notifications: RecordingNotifications) -> SnoozeScheduler {
        SnoozeScheduler(directory: TestStorage.makeDirectory(), notifications: notifications)
    }

    func testSnoozeAsksPermissionLazilyAndSchedulesAtWakeTime() {
        let notifications = RecordingNotifications()
        let scheduler = makeScheduler(notifications)
        XCTAssertEqual(notifications.permissionRequests, 0, "pas de demande d'autorisation au lancement")

        let wake = Date().addingTimeInterval(3600)
        scheduler.snooze(MockData.inbox()[0], until: wake)
        XCTAssertEqual(notifications.permissionRequests, 1)
        XCTAssertEqual(notifications.scheduled.count, 1)
        XCTAssertEqual(notifications.scheduled[0].at, wake)
    }

    func testNotificationNeverContainsSenderOrSubject() {
        let notifications = RecordingNotifications()
        let scheduler = makeScheduler(notifications)
        let card = MockData.inbox()[1]
        scheduler.snooze(card, until: Date().addingTimeInterval(60))
        let content = notifications.scheduled[0].title + " " + notifications.scheduled[0].body
        XCTAssertFalse(content.contains(card.senderName))
        XCTAssertFalse(content.contains(card.subject))
    }

    func testRemovingASnoozeCancelsItsNotification() {
        let notifications = RecordingNotifications()
        let scheduler = makeScheduler(notifications)
        let card = MockData.inbox()[0]
        scheduler.snooze(card, until: Date().addingTimeInterval(60))
        scheduler.remove(id: card.id)
        XCTAssertEqual(notifications.cancelled, [card.id])
    }

    func testSwitchingDataFolderCancelsAndReschedulesOnlyFutureItems() {
        let notifications = RecordingNotifications()
        let scheduler = makeScheduler(notifications)
        let other = TestStorage.makeDirectory()
        let seed = JSONFileStore<[SnoozeItem]>(filename: "snoozed.json", directory: other)
        let cards = MockData.inbox()
        seed.save([
            SnoozeItem(id: cards[0].id, card: cards[0], wakeAt: Date().addingTimeInterval(600)),
            SnoozeItem(id: cards[1].id, card: cards[1], wakeAt: Date().addingTimeInterval(-600)),
        ])
        scheduler.use(directory: other)
        XCTAssertEqual(scheduler.items.count, 2)
        XCTAssertEqual(notifications.scheduled.map(\.id), [cards[0].id])
    }

    func testRemoveAllCancelsEverything() {
        let notifications = RecordingNotifications()
        let scheduler = makeScheduler(notifications)
        let cards = MockData.inbox()
        scheduler.snooze(cards[0], until: Date().addingTimeInterval(60))
        scheduler.snooze(cards[1], until: Date().addingTimeInterval(60))
        scheduler.removeAll()
        XCTAssertEqual(Set(notifications.cancelled), [cards[0].id, cards[1].id])
        XCTAssertTrue(scheduler.items.isEmpty)
    }
}

@MainActor
final class LaunchPermissionTests: XCTestCase {
    /// La permission de notification ne doit être demandée qu'au premier snooze, jamais au lancement.
    func testNoPermissionRequestedByLaunchLoadingOrModeSwitch() async {
        let notifications = RecordingNotifications()
        let store = EmailStore(auth: AuthManager(), undoDelay: 0, storageDirectory: TestStorage.makeDirectory(), notifications: notifications)
        await store.loadInbox()
        await store.loadInbox(force: true)
        store.resurfaceDueSnoozes()
        store.enableMockPreview()
        store.exitMockPreview()
        await store.archive(store.inbox.first ?? MockData.inbox()[0]).value
        XCTAssertEqual(notifications.permissionRequests, 0)
    }

    func testFirstSnoozeRequestsPermissionExactlyThroughTheScheduler() async {
        let notifications = RecordingNotifications()
        let store = EmailStore(auth: AuthManager(), undoDelay: 0, storageDirectory: TestStorage.makeDirectory(), notifications: notifications)
        await store.loadInbox()
        await store.snooze(store.inbox[0], duration: .oneHour).value
        XCTAssertEqual(notifications.permissionRequests, 1)
        XCTAssertEqual(notifications.scheduled.count, 1)
    }
}
