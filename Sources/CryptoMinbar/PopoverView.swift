import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: TickerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: CryptoMinbarDesign.panelSpacing) {
            PriceHeroCard(
                ticker: viewModel.ticker,
                selectedCoin: viewModel.selectedCoin,
                statusTitle: viewModel.statusTitle,
                isRefreshing: viewModel.isRefreshing
            )

            CoinSelectorCard(viewModel: viewModel)

            MarketStatsCard(
                ticker: viewModel.ticker,
                lastUpdated: viewModel.lastUpdated
            )

            PopoverActionBar(
                errorMessage: viewModel.errorMessage,
                refresh: refreshNow,
                quit: quit
            )
        }
        .padding(CryptoMinbarDesign.contentPadding)
        .frame(width: CryptoMinbarDesign.panelWidth)
        .background {
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color(nsColor: .controlBackgroundColor)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func refreshNow() {
        Task { await viewModel.refreshNow() }
    }

    private func quit() {
        NSApp.terminate(nil)
    }
}
