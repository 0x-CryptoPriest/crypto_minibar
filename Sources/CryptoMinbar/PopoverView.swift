import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: TickerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: CryptoMinbarDesign.panelSpacing) {
            PriceHeroCard(
                ticker: viewModel.ticker,
                selectedCoin: viewModel.selectedCoin,
                feedMode: viewModel.feedMode,
                statusTitle: viewModel.statusTitle,
                isRefreshing: viewModel.isRefreshing,
                copyPrice: copyPrice
            )

            if viewModel.isShowingAPISettings {
                FeedSettingsCard(viewModel: viewModel)
            }

            CoinSelectorCard(viewModel: viewModel)

            MarketStatsCard(
                ticker: viewModel.ticker,
                lastUpdated: viewModel.lastUpdated
            )

            AlertsCard(viewModel: viewModel)

            PopoverActionBar(
                errorMessage: viewModel.errorMessage,
                isShowingSettings: viewModel.isShowingAPISettings,
                refresh: refreshNow,
                toggleSettings: toggleSettings,
                quit: quit
            )
        }
        .padding(CryptoMinbarDesign.contentPadding)
        .frame(width: CryptoMinbarDesign.panelWidth, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func copyPrice() {
        viewModel.copyPriceToClipboard()
    }

    private func refreshNow() {
        Task { await viewModel.refreshNow() }
    }

    private func toggleSettings() {
        viewModel.toggleAPISettings()
    }

    private func quit() {
        NSApp.terminate(nil)
    }
}
