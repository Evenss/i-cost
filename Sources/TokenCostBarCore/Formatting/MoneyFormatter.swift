import Foundation

public enum MoneyFormatter {
    public static func usd(_ value: Decimal) -> String {
        "$" + decimal(value, minimumFractionDigits: 2, maximumFractionDigits: 2)
    }

    public static func cny(_ value: Decimal) -> String {
        "¥" + decimal(value, minimumFractionDigits: 2, maximumFractionDigits: 2)
    }

    public static func statusBarUSD(_ value: Decimal) -> String {
        "$" + decimal(
            value,
            minimumFractionDigits: value >= 100 ? 0 : 2,
            maximumFractionDigits: value >= 100 ? 0 : 2
        )
    }

    private static func decimal(
        _ value: Decimal,
        minimumFractionDigits: Int,
        maximumFractionDigits: Int
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }
}
