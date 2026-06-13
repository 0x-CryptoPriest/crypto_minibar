import Foundation

enum DisplayFormatters {
    static let percent: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.positivePrefix = "+"
        return formatter
    }()

    static let price: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US")
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 4
        return formatter
    }()

    /// Signed percent number (no `%` suffix), e.g. "+0.42" / "-0.18", or "—".
    static func percentString(_ value: Decimal) -> String {
        percent.string(from: NSDecimalNumber(decimal: value)) ?? "—"
    }
}
