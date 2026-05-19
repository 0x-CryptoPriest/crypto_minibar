import SwiftUI

struct TrendPill: View {
    let value: Decimal
    let label: String

    private var isNegative: Bool {
        value < 0
    }

    var body: some View {
        Label("\(label) \(formattedValue)", systemImage: isNegative ? "arrow.down.right" : "arrow.up.right")
            .font(.callout)
            .monospacedDigit()
            .foregroundStyle(isNegative ? CryptoMinbarDesign.negative : CryptoMinbarDesign.positive)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background((isNegative ? CryptoMinbarDesign.negative : CryptoMinbarDesign.positive).opacity(0.12), in: Capsule())
            .accessibilityLabel("\(label) change \(formattedValue)")
    }

    private var formattedValue: String {
        let number = NSDecimalNumber(decimal: value)
        let formatted = DisplayFormatters.percent.string(from: number) ?? "--"
        return formatted
    }
}
