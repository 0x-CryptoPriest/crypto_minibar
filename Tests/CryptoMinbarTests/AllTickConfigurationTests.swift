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
}
