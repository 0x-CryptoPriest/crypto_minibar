import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: TickerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: CryptoMinbarDesign.sectionSpacing) {
            PriceHeroCard(
                selectedCoin: viewModel.selectedCoin,
                feedSourceLabel: viewModel.feedSourceLabel,
                priceText: viewModel.heroPriceText,
                ticker: viewModel.ticker,
                change: viewModel.primaryChange,
                changeLabel: viewModel.primaryWindow.label,
                connectionState: viewModel.connectionState,
                copyPrice: copyPrice
            )

            CoinSelectorCard(viewModel: viewModel)

            PriceChartCard(candles: viewModel.chartCandles)

            MarketStatsCard(viewModel: viewModel)

            AlertsCard(viewModel: viewModel)

            if viewModel.isShowingSettings {
                SettingsCard(viewModel: viewModel)
            }

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(CryptoMinbarDesign.negative)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Error: \(errorMessage)")
            }

            PopoverActionBar(
                isShowingSettings: viewModel.isShowingSettings,
                refresh: refreshNow,
                toggleSettings: toggleSettings,
                quit: quit
            )
        }
        .padding(CryptoMinbarDesign.contentPadding)
        .frame(width: CryptoMinbarDesign.panelWidth, alignment: .leading)
        .animation(.snappy(duration: 0.2), value: viewModel.isShowingSettings)
        .animation(.snappy(duration: 0.2), value: viewModel.errorMessage)
    }

    private func copyPrice() {
        viewModel.copyPriceToClipboard()
    }

    private func refreshNow() {
        Task { await viewModel.refreshNow() }
    }

    private func toggleSettings() {
        viewModel.toggleSettings()
    }

    private func quit() {
        NSApp.terminate(nil)
    }
}
