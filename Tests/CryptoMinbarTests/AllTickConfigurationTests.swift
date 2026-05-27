import Foundation
import Testing
@testable import CryptoMinbar

@Suite("AllTick configuration")
struct AllTickConfigurationTests {
    @Test("free account symbols are wired")
    func freeAccountSymbolsAreWired() {
        let symbols = CoinInfo.allTickSymbols.map(\.id)
        #expect(symbols == [
            "USDJPY",
            "GOLD",
            "USOIL",
            "HSI.HK",
            "BTCUSDT",
            ".DJI.US",
            "TSLA.US",
            "700.HK",
            "000001.SH",
            "399001.SZ"
        ])
    }

    @Test("symbols choose the correct websocket endpoint")
    func symbolsChooseCorrectWebsocketEndpoint() {
        #expect(CoinInfo.allTickSymbols[0].quoteEndpoint.url.absoluteString == "wss://quote.alltick.co/quote-b-ws-api")
        #expect(CoinInfo.allTickSymbols[3].quoteEndpoint.url.absoluteString == "wss://quote.alltick.co/quote-stock-b-ws-api")
    }

    @Test("premium symbols are scoped to BTC")
    func premiumSymbolsAreScopedToBtc() {
        #expect(CoinInfo.premiumSymbols.map(\.id) == ["BTCUSDT"])
    }

    @Test("public exchange providers share the crypto catalog")
    func publicExchangeProvidersShareTheCryptoCatalog() {
        let symbols = CoinInfo.exchangeSymbols.map(\.id)
        #expect(symbols == ["BTCUSDT", "ETHUSDT", "SOLUSDT"])
        #expect(StandardFeedProvider.binance.supportedCoins.map(\.id) == symbols)
        #expect(StandardFeedProvider.okx.supportedCoins.map(\.id) == symbols)
        #expect(StandardFeedProvider.hyperliquid.supportedCoins.map(\.id) == symbols)
    }

    @Test("exchange providers map internal symbols to websocket symbols")
    func exchangeProvidersMapSymbols() {
        #expect(StandardFeedProvider.binance.streamSymbol(for: .bitcoin) == "BTCUSDT")
        #expect(StandardFeedProvider.okx.streamSymbol(for: .bitcoin) == "BTC-USDT")
        #expect(StandardFeedProvider.hyperliquid.streamSymbol(for: .bitcoin) == "BTC")
        #expect(StandardFeedProvider.okx.streamSymbol(for: .ethereum) == "ETH-USDT")
        #expect(StandardFeedProvider.hyperliquid.streamSymbol(for: .solana) == "SOL")
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
