import XCTest
@testable import MailSwipe

final class SnoozeDurationTests: XCTestCase {
    private let calendar = Calendar.current

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    func testOneHourAddsSixtyMinutes() {
        let now = date(2026, 9, 22, 10, 30)
        XCTAssertEqual(SnoozeDuration.oneHour.resolvedDate(from: now), date(2026, 9, 22, 11, 30))
    }

    func testThisEveningBeforeSixIsToday() {
        let now = date(2026, 9, 22, 10)
        XCTAssertEqual(SnoozeDuration.thisEvening.resolvedDate(from: now), date(2026, 9, 22, 18))
    }

    func testThisEveningAfterSixRollsToTomorrow() {
        let now = date(2026, 9, 22, 19)
        XCTAssertEqual(SnoozeDuration.thisEvening.resolvedDate(from: now), date(2026, 9, 23, 18))
    }

    func testTomorrowMorningBeforeEightIsToday() {
        let now = date(2026, 9, 22, 6)
        XCTAssertEqual(SnoozeDuration.tomorrowMorning.resolvedDate(from: now), date(2026, 9, 22, 8))
    }

    func testTomorrowMorningAfterEightIsNextDay() {
        let now = date(2026, 9, 22, 10)
        XCTAssertEqual(SnoozeDuration.tomorrowMorning.resolvedDate(from: now), date(2026, 9, 23, 8))
    }

    func testNextWeekAddsSevenDays() {
        let now = date(2026, 9, 22, 10)
        XCTAssertEqual(SnoozeDuration.nextWeek.resolvedDate(from: now), date(2026, 9, 29, 10))
    }
}
