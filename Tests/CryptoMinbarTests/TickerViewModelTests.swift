import Foundation
import Testing
@testable import CryptoMinbar

@Suite("Ticker view model")
struct TickerViewModelTests {
    @MainActor
    @Test("starts with BTC placeholder before websocket tick")
    func startsWithBTCPlaceholder() {
        let viewModel = TickerViewModel(streamProvider: MockTickerStreamProvider())

        #expect(viewModel.statusTitle == "BTC --")
    }
}

struct MockTickerStreamProvider: TickerStreamProvider {
    func streamTicker(token: String, symbol: String) -> AsyncThrowingStream<BTCTicker, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(BTCTicker(
                id: symbol,
                symbol: "BTC",
                name: "Bitcoin",
                nameid: "bitcoin",
                rank: 1,
                date: Date(),
                priceUSD: 100,
                percentChange5m: nil,
                percentChange15m: nil,
                marketCapUSD: nil,
                volume24: nil
            ))
            continuation.finish()
        }
    }
}
