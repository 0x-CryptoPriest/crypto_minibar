import SwiftUI

struct TrendPill: View {
    let value: Decimal
    let label: String

    private var isNegative: Bool {
        value < 0
    }

    private var tint: Color {
        isNegative ? CryptoMinbarDesign.negative : CryptoMinbarDesign.positive
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: isNegative ? "arrow.down.right" : "arrow.up.right")
                .font(.caption.weight(.bold))
            Text("\(formattedValue)%")
                .monospacedDigit()
            Text(label)
                .foregroundStyle(.secondary)
        }
        .font(.callout)
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.12), in: Capsule())
        .accessibilityLabel("\(label) change \(formattedValue) percent")
    }

    private var formattedValue: String {
        DisplayFormatters.percentString(value)
    }
}
