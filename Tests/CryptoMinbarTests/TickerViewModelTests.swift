import Foundation
import Testing
@testable import CryptoMinbar

@Suite("Ticker view model")
struct TickerViewModelTests {
    @MainActor
    @Test("each successful refresh updates the displayed price")
    func eachSuccessfulRefreshUpdatesDisplayedPrice() async {
        let provider = SequenceProvider(tickers: [
            Self.ticker(price: "100.00"),
            Self.ticker(price: "101.25")
        ])
        let viewModel = TickerViewModel(provider: provider)

        await viewModel.refreshNow()
        #expect(viewModel.statusTitle == "BTC $100.00")

        await viewModel.refreshNow()
        #expect(viewModel.statusTitle == "BTC $101.25")
    }

    private static func ticker(price: String) -> BTCTicker {
        BTCTicker(
            id: "90",
            symbol: "BTC",
            name: "Bitcoin",
            nameid: "bitcoin",
            rank: 1,
            priceUSD: Decimal(string: price)!,
            percentChange1h: nil,
            percentChange24h: nil,
            percentChange4h: nil,
            marketCapUSD: nil,
            volume24: nil
        )
    }
}

actor SequenceProvider: MarketDataProvider {
    private var tickers: [BTCTicker]

    init(tickers: [BTCTicker]) {
        self.tickers = tickers
    }

    func fetchAssets() async throws -> [CoinInfo] {
        [.bitcoin]
    }

    func fetchTicker(id: String) async throws -> BTCTicker {
        tickers.removeFirst()
    }
}
