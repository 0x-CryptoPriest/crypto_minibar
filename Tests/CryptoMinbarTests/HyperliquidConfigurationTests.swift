import Foundation
import Testing
@testable import CryptoMinbar

@Suite("Hyperliquid configuration")
struct HyperliquidConfigurationTests {
    @Test("supported catalog is BTC/ETH/SOL")
    func supportedCatalogIsBtcEthSol() {
        #expect(CoinInfo.supportedSymbols.map(\.id) == ["BTCUSDT", "ETHUSDT", "SOLUSDT"])
    }

    @Test("coins map to hyperliquid stream symbols")
    func coinsMapToHyperliquidStreamSymbols() {
        #expect(CoinInfo.bitcoin.hyperliquidSymbol == "BTC")
        #expect(CoinInfo.ethereum.hyperliquidSymbol == "ETH")
        #expect(CoinInfo.solana.hyperliquidSymbol == "SOL")
    }

    @Test("hyperliquid ignores subscription acknowledgements")
    func hyperliquidIgnoresSubscriptionAcknowledgements() throws {
        let acknowledgement = """
        {"channel":"subscriptionResponse","data":{"method":"subscribe","subscription":{"type":"trades","coin":"BTC"}}}
        """

        #expect(try HyperliquidTradeDecoder.decodeTrade(from: acknowledgement, expectedSymbol: "BTC") == nil)
    }

    @Test("hyperliquid decodes trade frames")
    func hyperliquidDecodesTradeFrames() throws {
        let trade = """
        {"channel":"trades","data":[{"coin":"BTC","side":"A","px":"75743.0","sz":"0.00132","time":1779847758283,"hash":"0x0","tid":1,"users":[]}]}
        """

        let decoded = try HyperliquidTradeDecoder.decodeTrade(from: trade, expectedSymbol: "BTC")

        #expect(decoded?.price == Decimal(string: "75743.0", locale: Locale(identifier: "en_US_POSIX")))
        #expect(decoded?.date == Date(timeIntervalSince1970: 1_779_847_758.283))
    }
}
