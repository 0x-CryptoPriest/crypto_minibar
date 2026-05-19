import SwiftUI

struct MarketStatsCard: View {
    let ticker: BTCTicker?
    let lastUpdated: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                StatTile(title: "5min", value: percentText(ticker?.percentChange5m), tone: tone(for: ticker?.percentChange5m))
                StatTile(title: "15min", value: percentText(ticker?.percentChange15m), tone: tone(for: ticker?.percentChange15m))
            }

            HStack {
                Label("Runtime tick history · 20min memory", systemImage: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(updatedText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: 68, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var updatedText: String {
        guard let lastUpdated else {
            return "--"
        }
        return lastUpdated.formatted(date: .omitted, time: .standard)
    }

    private func percentText(_ value: Decimal?) -> String {
        guard let value else {
            return "--"
        }
        let number = NSDecimalNumber(decimal: value)
        let formatted = DisplayFormatters.percent.string(from: number) ?? "--"
        return "\(formatted)%"
    }

    private func tone(for value: Decimal?) -> StatTile.Tone {
        guard let value else {
            return .neutral
        }
        return value < 0 ? .negative : .positive
    }
}
