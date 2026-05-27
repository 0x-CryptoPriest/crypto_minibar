import Foundation
import Testing
@testable import CryptoMinbar

@Suite("Ticker view model")
struct TickerViewModelTests {
    @MainActor
    @Test("starts with the selected symbol placeholder before websocket tick")
    func startsWithSelectedSymbolPlaceholder() {
        resetTickerPreferences()
        let viewModel = TickerViewModel(streamProvider: MockTickerStreamProvider())

        #expect(viewModel.statusTitle == "USD/JPY --")
    }

    @MainActor
    @Test("defaults to USDJPY")
    func defaultsToUsdJpy() {
        resetTickerPreferences()
        let viewModel = TickerViewModel(streamProvider: MockTickerStreamProvider())

        #expect(viewModel.selectedCoin.id == "USDJPY")
        #expect(viewModel.feedMode == .standard)
    }

    @MainActor
    @Test("switches websocket subscriptions one at a time")
    func switchesWebSocketSubscriptionsOneAtATime() async {
        resetTickerPreferences()
        let provider = RecordingTickerStreamProvider()
        let viewModel = TickerViewModel(
            streamProvider: provider,
            tokenStore: MockTokenStore(token: "test-token")
        )

        viewModel.start()
        #expect(await waitUntil { provider.snapshot.startedSymbols.count == 1 })

        viewModel.selectCoin(CoinInfo.allTickSymbols[1])
        #expect(await waitUntil { provider.snapshot.startedSymbols.count == 2 })
        #expect(provider.snapshot.maxActiveStreams == 1)
        #expect(provider.snapshot.startedSymbols == ["USDJPY", "GOLD"])
        #expect(provider.snapshot.terminatedSymbols == ["USDJPY"])
    }

    @MainActor
    @Test("premium mode loads the premium catalog")
    func premiumModeLoadsThePremiumCatalog() {
        resetTickerPreferences()
        UserDefaults.standard.set("premium", forKey: "feedMode")
        UserDefaults.standard.set("BTCUSDT", forKey: "selectedPremiumCoinID")

        let viewModel = TickerViewModel(streamProvider: MockTickerStreamProvider())

        #expect(viewModel.feedMode == .premium)
        #expect(viewModel.coins == CoinInfo.premiumSymbols)
        #expect(viewModel.selectedCoin.id == "BTCUSDT")
    }

    @MainActor
    @Test("standard and premium streams are mutually exclusive")
    func standardAndPremiumStreamsAreMutuallyExclusive() async {
        resetTickerPreferences()
        let standardProvider = RecordingTickerStreamProvider()
        let premiumProvider = RecordingTickerStreamProvider()
        let viewModel = TickerViewModel(
            streamProvider: standardProvider,
            premiumStreamProviderFactory: { _ in premiumProvider },
            tokenStore: MockTokenStore(token: "standard-token"),
            premiumTokenStore: MockPremiumTokenStore(token: "premium-token")
        )

        viewModel.start()
        #expect(await waitUntil { standardProvider.snapshot.startedSymbols == ["USDJPY"] })

        viewModel.selectFeedMode(.premium)
        #expect(await waitUntil { premiumProvider.snapshot.startedSymbols == ["BTCUSDT"] })
        #expect(standardProvider.snapshot.terminatedSymbols == ["USDJPY"])
        #expect(standardProvider.snapshot.maxActiveStreams == 1)
        #expect(premiumProvider.snapshot.maxActiveStreams == 1)
    }

    @MainActor
    @Test("switching standard provider loads public crypto and connects without API key")
    func switchingStandardProviderLoadsPublicCryptoAndConnectsWithoutApiKey() async {
        resetTickerPreferences()
        let provider = RecordingTickerStreamProvider()
        let viewModel = TickerViewModel(
            streamProvider: provider,
            tokenStore: MockTokenStore(token: nil)
        )

        viewModel.start()
        #expect(provider.snapshot.startedSymbols.isEmpty)

        viewModel.selectStandardFeedProvider(.binance)

        #expect(viewModel.standardFeedProvider == .binance)
        #expect(viewModel.coins == CoinInfo.exchangeSymbols)
        #expect(viewModel.selectedCoin.id == "BTCUSDT")
        #expect(await waitUntil { provider.snapshot.startedSymbols == ["BTCUSDT"] })
    }
}

private func resetTickerPreferences() {
    let keys = [
        "feedMode",
        "standardFeedProvider",
        "selectedCoinID",
        "selectedStandardCoinID",
        "selectedPremiumCoinID",
        "premiumFeedURL"
    ] + StandardFeedProvider.allCases.map { "selectedStandardCoinID.\($0.rawValue)" }

    for key in keys {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

struct MockTickerStreamProvider: TickerStreamProvider {
    func streamTicker(token: String, symbol: String) -> AsyncThrowingStream<BTCTicker, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(BTCTicker(
                id: symbol,
                symbol: "USD/JPY",
                name: "US Dollar / Japanese Yen",
                nameid: "usd-jpy",
                rank: 1,
                date: Date(),
                price: 100,
                percentChange5m: nil,
                percentChange15m: nil,
                marketCapUSD: nil,
                volume24: nil
            ))
            continuation.finish()
        }
    }
}

struct MockTokenStore: AllTickTokenStoring {
    let token: String?

    func readToken() -> String? {
        token
    }

    func saveToken(_ token: String) throws {}

    func deleteToken() throws {}
}

struct MockPremiumTokenStore: PremiumUserTokenStoring {
    let token: String?

    func readToken() -> String? {
        token
    }

    func saveToken(_ token: String) throws {}

    func deleteToken() throws {}
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

    func streamTicker(token: String, symbol: String) -> AsyncThrowingStream<BTCTicker, Error> {
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
                percentChange5m: nil,
                percentChange15m: nil,
                marketCapUSD: nil,
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
