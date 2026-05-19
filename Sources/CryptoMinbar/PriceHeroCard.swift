import SwiftUI

struct PriceHeroCard: View {
    let ticker: BTCTicker?
    let selectedCoin: CoinInfo
    let statusTitle: String
    let isRefreshing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: CryptoMinbarDesign.cardSpacing) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Label(selectedCoin.name, systemImage: "bitcoinsign.circle.fill")
                        .font(.headline)
                        .labelStyle(.titleAndIcon)
                        .symbolRenderingMode(.hierarchical)

                    Text("Yahoo Finance · \(selectedCoin.id)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                RefreshBadge(isRefreshing: isRefreshing)
            }

            Text(statusTitle)
                .font(.system(.largeTitle, design: .rounded).bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .accessibilityLabel("\(selectedCoin.name) price \(statusTitle)")

            if let ticker, let change = ticker.percentChange24h {
                TrendPill(value: change, label: "24h")
            } else {
                Text("Waiting for the next quote")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(CryptoMinbarDesign.contentPadding)
        .background {
            RoundedRectangle(cornerRadius: CryptoMinbarDesign.cornerRadius)
                .fill(.regularMaterial)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(CryptoMinbarDesign.accent.gradient)
                        .frame(width: 96, height: 96)
                        .blur(radius: 32)
                        .opacity(0.35)
                        .offset(x: 18, y: -32)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: CryptoMinbarDesign.cornerRadius))
    }
}
