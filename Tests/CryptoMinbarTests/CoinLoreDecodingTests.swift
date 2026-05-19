import Foundation
import Testing
@testable import CryptoMinbar

@Suite("AllTick configuration")
struct AllTickConfigurationTests {
    @Test("bitcoin uses AllTick BTCUSDT symbol")
    func bitcoinUsesAllTickSymbol() {
        #expect(CoinInfo.bitcoin.id == "BTCUSDT")
        #expect(CoinInfo.bitcoin.symbol == "BTC")
    }
}
