import Foundation

enum DateUtils {
    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.gmt
        return calendar
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.gmt
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Returns today's date as "YYYY-MM-DD" floored to UTC.
    static func currentUTCDate() -> String {
        dateFormatter.string(from: Date())
    }

    /// Returns whether the given UTC date string matches today's UTC date.
    static func isToday(utcDate: String) -> Bool {
        utcDate == currentUTCDate()
    }

    /// Returns the number of days between two "YYYY-MM-DD" UTC date strings.
    /// Returns 0 if either date is invalid.
    static func daysBetween(from: String, to: String) -> Int {
        guard let fromDate = dateFormatter.date(from: from),
              let toDate = dateFormatter.date(from: to) else {
            return 0
        }
        let components = utcCalendar.dateComponents([.day], from: fromDate, to: toDate)
        return components.day ?? 0
    }

    /// Formats a Date to "YYYY-MM-DD" in UTC.
    static func formatUTC(date: Date) -> String {
        dateFormatter.string(from: date)
    }

    /// Parses a "YYYY-MM-DD" string into a Date in UTC.
    static func parseUTC(dateString: String) -> Date? {
        dateFormatter.date(from: dateString)
    }
}
