import AppKit
import SwiftUI

struct PriceHeroCard: View {
    let ticker: BTCTicker?
    let selectedCoin: CoinInfo
    let statusTitle: String
    let isRefreshing: Bool
    let copyPrice: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CryptoMinbarDesign.cardSpacing) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Label(selectedCoin.name, systemImage: selectedCoin.symbolName)
                        .font(.headline)
                        .labelStyle(.titleAndIcon)
                        .symbolRenderingMode(.hierarchical)

                    Text("AllTick WebSocket · \(selectedCoin.id)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: copyPrice) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Copy price to clipboard")
                .opacity(ticker != nil ? 1 : 0.3)

                RefreshBadge(isRefreshing: isRefreshing)
            }

            Text(statusTitle)
                .font(.system(.largeTitle, design: .rounded).bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .accessibilityLabel("\(selectedCoin.name) price \(statusTitle)")

            if let ticker, let change = ticker.percentChange5m {
                TrendPill(value: change, label: "5min")
            } else {
                Text("Waiting for the next quote")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(CryptoMinbarDesign.contentPadding)
        .frame(minHeight: 148, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: CryptoMinbarDesign.cornerRadius)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: CryptoMinbarDesign.cornerRadius)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: CryptoMinbarDesign.cornerRadius))
    }
}
