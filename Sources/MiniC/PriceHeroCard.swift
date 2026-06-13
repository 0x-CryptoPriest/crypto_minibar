import SwiftUI

struct PriceHeroCard: View {
    let selectedCoin: CoinInfo
    let feedSourceLabel: String
    let priceText: String
    let ticker: BTCTicker?
    let change: Decimal?
    let changeLabel: String
    let connectionState: ConnectionState
    let copyPrice: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: selectedCoin.symbolName)
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(CryptoMinbarDesign.accent)

                VStack(alignment: .leading, spacing: 1) {
                    Text(selectedCoin.name)
                        .font(.headline)
                        .lineLimit(1)

                    Text("\(selectedCoin.symbol) · \(feedSourceLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                ConnectionStatusDot(state: connectionState)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(priceText)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: priceText)
                    .accessibilityLabel("\(selectedCoin.name) price \(priceText)")

                Spacer(minLength: 4)

                Button(action: copyPrice) {
                    Image(systemName: "square.on.square")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Copy price to clipboard")
                .opacity(ticker != nil ? 1 : 0.3)
                .disabled(ticker == nil)
            }

            Group {
                if let change {
                    TrendPill(value: change, label: changeLabel)
                } else {
                    Label("Waiting for the next quote", systemImage: "clock")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            // Fixed height so the card doesn't grow when the change pill replaces
            // the placeholder (which would shift the popover as data loads).
            .frame(height: 30, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(CryptoMinbarDesign.contentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}
