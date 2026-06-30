import Foundation

enum DateFormats {
    static func string(from date: Date) -> String {
        iso8601Formatter(withFractionalSeconds: true).string(from: date)
    }

    static func date(from string: String) -> Date? {
        iso8601Formatter(withFractionalSeconds: true).date(from: string)
            ?? iso8601Formatter(withFractionalSeconds: false).date(from: string)
            ?? timestampFormatter().date(from: string)
            ?? dateOnlyFormatter().date(from: string)
    }

    static func dayString(from date: Date) -> String {
        dayFormatter().string(from: date)
    }

    static func dayDate(from string: String) -> Date? {
        dayFormatter().date(from: string)
    }

    private static func iso8601Formatter(withFractionalSeconds: Bool) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = withFractionalSeconds
            ? [.withInternetDateTime, .withFractionalSeconds]
            : [.withInternetDateTime]
        return formatter
    }

    private static func dayFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private static func timestampFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }

    private static func dateOnlyFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
