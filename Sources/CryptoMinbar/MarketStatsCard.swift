import SwiftUI

struct MarketStatsCard: View {
    let ticker: BTCTicker?
    let lastUpdated: Date?

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
            GridRow {
                StatTile(title: "1h", value: percentText(ticker?.percentChange1h), tone: tone(for: ticker?.percentChange1h))
                StatTile(title: "24h", value: percentText(ticker?.percentChange24h), tone: tone(for: ticker?.percentChange24h))
            }

            GridRow {
                StatTile(title: "4h", value: percentText(ticker?.percentChange4h), tone: tone(for: ticker?.percentChange4h))
                StatTile(title: "Updated", value: updatedText, tone: .neutral)
            }
        }
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
