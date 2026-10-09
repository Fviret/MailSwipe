import XCTest
import Combine
@testable import MailSwipe

@MainActor
final class ObservationTests: XCTestCase {
    func testStorePublishesWhenTheSnoozeSchedulerChanges() async {
        let store = EmailStore(auth: AuthManager(), undoDelay: 0, storageDirectory: TestStorage.makeDirectory(), notifications: RecordingNotifications())
        await store.loadInbox()
        store.snoozeScheduler.snooze(store.inbox[0], until: Date().addingTimeInterval(60))

        var changes = 0
        let subscription = store.objectWillChange.sink { changes += 1 }
        store.snoozeScheduler.remove(id: store.inbox[0].id)
        XCTAssertGreaterThan(changes, 0, "les vues qui lisent store.snoozeScheduler.items doivent être invalidées")
        subscription.cancel()
    }

    func testSwitchingDataFolderAlsoInvalidatesViews() {
        let store = EmailStore(auth: AuthManager(), undoDelay: 0, storageDirectory: TestStorage.makeDirectory(), notifications: RecordingNotifications())
        var changes = 0
        let subscription = store.objectWillChange.sink { changes += 1 }
        store.snoozeScheduler.use(directory: TestStorage.makeDirectory())
        XCTAssertGreaterThan(changes, 0)
        subscription.cancel()
    }
}
