import XCTest
@testable import Calibrate

final class DateUtilsTests: XCTestCase {

    // MARK: - currentUTCDate format

    func testCurrentUTCDateFormat() {
        let result = DateUtils.currentUTCDate()
        // Should match YYYY-MM-DD format
        let regex = /^\d{4}-\d{2}-\d{2}$/
        XCTAssertNotNil(result.wholeMatch(of: regex), "Expected YYYY-MM-DD format, got: \(result)")
    }

    // MARK: - isToday

    func testIsTodayMatchesCurrentUTCDate() {
        let today = DateUtils.currentUTCDate()
        XCTAssertTrue(DateUtils.isToday(utcDate: today))
    }

    func testIsTodayRejectsOtherDate() {
        XCTAssertFalse(DateUtils.isToday(utcDate: "2020-01-01"))
    }

    // MARK: - daysBetween

    func testDaysBetweenSameDate() {
        let days = DateUtils.daysBetween(from: "2026-03-22", to: "2026-03-22")
        XCTAssertEqual(days, 0)
    }

    func testDaysBetweenConsecutiveDates() {
        let days = DateUtils.daysBetween(from: "2026-03-22", to: "2026-03-23")
        XCTAssertEqual(days, 1)
    }

    func testDaysBetweenNegative() {
        let days = DateUtils.daysBetween(from: "2026-03-23", to: "2026-03-22")
        XCTAssertEqual(days, -1)
    }

    func testDaysBetweenAcrossMonthBoundary() {
        let days = DateUtils.daysBetween(from: "2026-03-30", to: "2026-04-02")
        XCTAssertEqual(days, 3)
    }

    func testDaysBetweenAcrossYearBoundary() {
        let days = DateUtils.daysBetween(from: "2025-12-31", to: "2026-01-01")
        XCTAssertEqual(days, 1)
    }

    func testDaysBetweenInvalidDateReturnsZero() {
        let days = DateUtils.daysBetween(from: "not-a-date", to: "2026-03-22")
        XCTAssertEqual(days, 0)
    }

    // MARK: - formatUTC / parseUTC round-trip

    func testFormatAndParseRoundTrip() {
        let dateString = "2026-06-15"
        guard let parsed = DateUtils.parseUTC(dateString: dateString) else {
            XCTFail("Failed to parse \(dateString)")
            return
        }
        let formatted = DateUtils.formatUTC(date: parsed)
        XCTAssertEqual(formatted, dateString)
    }

    func testParseInvalidReturnsNil() {
        XCTAssertNil(DateUtils.parseUTC(dateString: "invalid"))
        XCTAssertNil(DateUtils.parseUTC(dateString: ""))
    }

    // MARK: - UTC midnight edge case

    func testUTCMidnightEdgeCase() {
        // Create a date at 23:59 UTC on March 22
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.gmt
        let components = DateComponents(year: 2026, month: 3, day: 22, hour: 23, minute: 59, second: 59)
        guard let lateDate = calendar.date(from: components) else {
            XCTFail("Could not construct date")
            return
        }
        let formatted = DateUtils.formatUTC(date: lateDate)
        XCTAssertEqual(formatted, "2026-03-22", "23:59:59 UTC should still be March 22")

        // One second later should be March 23
        let nextDay = lateDate.addingTimeInterval(1)
        let nextFormatted = DateUtils.formatUTC(date: nextDay)
        XCTAssertEqual(nextFormatted, "2026-03-23", "00:00:00 UTC should be March 23")
    }
}
