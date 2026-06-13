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

        #expect(viewModel.statusTitle == "BTC/USDT --")
    }

    @MainActor
    @Test("defaults to BTCUSDT on Hyperliquid")
    func defaultsToBtcUsdt() {
        resetTickerPreferences()
        let viewModel = TickerViewModel(streamProvider: MockTickerStreamProvider())

        #expect(viewModel.selectedCoin.id == "BTCUSDT")
        #expect(viewModel.coins == CoinInfo.supportedSymbols)
        #expect(viewModel.feedSourceLabel == "Hyperliquid")
    }

    @MainActor
    @Test("connects to the public feed without any credentials")
    func connectsWithoutCredentials() async {
        resetTickerPreferences()
        let provider = RecordingTickerStreamProvider()
        let viewModel = TickerViewModel(streamProvider: provider)

        viewModel.start()

        #expect(await waitUntil { provider.snapshot.startedSymbols == ["BTCUSDT"] })
    }

    @MainActor
    @Test("switches websocket subscriptions one at a time")
    func switchesWebSocketSubscriptionsOneAtATime() async {
        resetTickerPreferences()
        let provider = RecordingTickerStreamProvider()
        let viewModel = TickerViewModel(streamProvider: provider)

        viewModel.start()
        #expect(await waitUntil { provider.snapshot.startedSymbols == ["BTCUSDT"] })

        viewModel.selectCoin(CoinInfo.ethereum)
        #expect(await waitUntil { provider.snapshot.startedSymbols == ["BTCUSDT", "ETHUSDT"] })
        #expect(provider.snapshot.maxActiveStreams == 1)
        #expect(provider.snapshot.terminatedSymbols == ["BTCUSDT"])
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
                percentChange5m: nil,
                percentChange15m: nil,
                marketCapUSD: nil,
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
