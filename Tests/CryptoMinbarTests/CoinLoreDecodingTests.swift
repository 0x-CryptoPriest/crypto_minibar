import Foundation
import Testing
@testable import CryptoMinbar

@Suite("Yahoo Finance decoding")
struct YahooFinanceDecodingTests {
    @Test("assets provide Yahoo USD symbols")
    func assetsProvideYahooUSDSymbols() {
        #expect(CoinInfo.bitcoin.id == "BTC-USD")
        #expect(CoinInfo.yahooCryptoUSD.map(\.symbol).prefix(3) == ["BTC", "ETH", "XRP"])
    }
}
