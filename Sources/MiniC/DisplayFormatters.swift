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

    private static let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US")
        formatter.usesGroupingSeparator = true
        return formatter
    }()

    /// Signed percent number (no `%` suffix), e.g. "+0.42" / "-0.18", or "—".
    static func percentString(_ value: Decimal) -> String {
        percent.string(from: NSDecimalNumber(decimal: value)) ?? "—"
    }

    /// Grouped price string with magnitude-adaptive precision (no currency
    /// symbol), so sub-dollar coins (e.g. $0.0000123) don't collapse to "$0.00"
    /// while large prices keep two decimals.
    static func priceString(_ value: Decimal) -> String {
        let magnitude = abs((value as NSDecimalNumber).doubleValue)
        let maxFraction: Int
        switch magnitude {
        case 0:
            maxFraction = 2
        case 1000...:
            maxFraction = 2
        case 1...:
            // $1–$1000: keep a few decimals (e.g. $2.2241) but trim trailing zeros.
            maxFraction = 4
        default:
            // Sub-$1: enough decimals for ~5 significant figures past the leading zeros.
            let leadingZeros = max(0, Int(floor(-log10(magnitude))))
            maxFraction = min(leadingZeros + 5, 10)
        }
        priceFormatter.minimumFractionDigits = 2
        priceFormatter.maximumFractionDigits = maxFraction
        return priceFormatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }
}
