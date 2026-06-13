import Foundation
import Testing
@testable import CryptoMinbar

@Suite("Ticker view model")
struct TickerViewModelTests {
    @MainActor
    @Test("starts with the selected symbol placeholder before websocket tick")
    func startsWithSelectedSymbolPlaceholder() {
        resetTickerPreferences()
        let viewModel = TickerViewModel(streamProvider: MockTickerStreamProvider(), candleService: StubCandleService(), catalogService: StubCatalogService())

        #expect(viewModel.statusTitle == "BTC --")
    }

    @MainActor
    @Test("defaults to BTC on Hyperliquid")
    func defaultsToBtcUsdt() {
        resetTickerPreferences()
        let viewModel = TickerViewModel(streamProvider: MockTickerStreamProvider(), candleService: StubCandleService(), catalogService: StubCatalogService())

        #expect(viewModel.selectedCoin.id == "BTC")
        #expect(viewModel.coins == CoinInfo.defaultSymbols)
        #expect(viewModel.feedSourceLabel == "Hyperliquid")
    }

    @MainActor
    @Test("connects to the public feed without any credentials")
    func connectsWithoutCredentials() async {
        resetTickerPreferences()
        let provider = RecordingTickerStreamProvider()
        let viewModel = TickerViewModel(streamProvider: provider, candleService: StubCandleService(), catalogService: StubCatalogService())

        viewModel.start()

        #expect(await waitUntil { provider.snapshot.startedSymbols == ["BTC"] })
    }

    @MainActor
    @Test("switches websocket subscriptions one at a time")
    func switchesWebSocketSubscriptionsOneAtATime() async {
        resetTickerPreferences()
        let provider = RecordingTickerStreamProvider()
        let viewModel = TickerViewModel(streamProvider: provider, candleService: StubCandleService(), catalogService: StubCatalogService())

        viewModel.start()
        #expect(await waitUntil { provider.snapshot.startedSymbols == ["BTC"] })

        viewModel.selectCoin(CoinInfo.hyperliquid("ETH"))
        #expect(await waitUntil { provider.snapshot.startedSymbols == ["BTC", "ETH"] })
        #expect(provider.snapshot.maxActiveStreams == 1)
        #expect(provider.snapshot.terminatedSymbols == ["BTC"])
    }

    @MainActor
    @Test("computes the change from the historical baseline, not from zero")
    func computesChangeFromBaseline() async {
        resetTickerPreferences()
        let provider = RecordingTickerStreamProvider() // yields price 100
        let now = Date()
        let candles = [
            PriceCandle(closeTime: now.addingTimeInterval(-3600), close: 80), // 1h ago
            PriceCandle(closeTime: now.addingTimeInterval(-300), close: 95)    // 5m ago
        ]
        let viewModel = TickerViewModel(
            streamProvider: provider,
            candleService: StubCandleService(candles),
            catalogService: StubCatalogService()
        )

        viewModel.start() // primaryWindow defaults to 1h → reference close 80

        #expect(await waitUntil { viewModel.primaryChange != nil })
        #expect(viewModel.primaryChange == 25) // (100 - 80) / 80 * 100
    }
}

struct StubCandleService: CandleProviding {
    let candles: [PriceCandle]

    init(_ candles: [PriceCandle] = []) {
        self.candles = candles
    }

    func candles(coinID: String) async throws -> [PriceCandle] {
        candles
    }
}

struct StubCatalogService: CoinCatalogProviding {
    let names: [String]

    init(_ names: [String] = []) {
        self.names = names
    }

    func coins() async throws -> [String] {
        names
    }
}

private func resetTickerPreferences() {
    for key in ["selectedCoinID", "priceAlerts", "showChangeInBar"] {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

struct MockTickerStreamProvider: TickerStreamProvider {
    func streamTicker(symbol: String) -> AsyncThrowingStream<BTCTicker, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(BTCTicker(
                id: symbol,
                symbol: "BTC/USDT",
                name: "Bitcoin/Tether",
                nameid: "bitcoin-tether",
                rank: 1,
                date: Date(),
                price: 100,
                volume24: nil
            ))
            continuation.finish()
        }
    }
}

final class RecordingTickerStreamProvider: TickerStreamProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var activeStreams = 0
    private var maxActiveStreams = 0
    private(set) var startedSymbols: [String] = []
    private(set) var terminatedSymbols: [String] = []

    var snapshot: Snapshot {
        lock.lock()
        defer { lock.unlock() }
        return Snapshot(
            activeStreams: activeStreams,
            maxActiveStreams: maxActiveStreams,
            startedSymbols: startedSymbols,
            terminatedSymbols: terminatedSymbols
        )
    }

    func streamTicker(symbol: String) -> AsyncThrowingStream<BTCTicker, Error> {
        lock.lock()
        activeStreams += 1
        maxActiveStreams = max(maxActiveStreams, activeStreams)
        startedSymbols.append(symbol)
        lock.unlock()

        return AsyncThrowingStream { continuation in
            continuation.yield(BTCTicker(
                id: symbol,
                symbol: symbol,
                name: symbol,
                nameid: symbol.lowercased(),
                rank: 1,
                date: Date(),
                price: 100,
                volume24: nil
            ))

            continuation.onTermination = { @Sendable _ in
                Thread.sleep(forTimeInterval: 0.1)
                self.lock.lock()
                self.activeStreams -= 1
                self.terminatedSymbols.append(symbol)
                self.lock.unlock()
            }
        }
    }

    struct Snapshot: Sendable {
        let activeStreams: Int
        let maxActiveStreams: Int
        let startedSymbols: [String]
        let terminatedSymbols: [String]
    }
}

@MainActor
private func waitUntil(
    timeoutNanoseconds: UInt64 = 2_000_000_000,
    condition: @escaping () -> Bool
) async -> Bool {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
    while DispatchTime.now().uptimeNanoseconds < deadline {
        if condition() {
            return true
        }
        await Task.yield()
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
    return condition()
}
