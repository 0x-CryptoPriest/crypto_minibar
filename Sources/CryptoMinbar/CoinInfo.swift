import Foundation

struct CoinInfo: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let symbol: String
    let name: String
    let nameid: String
    let rank: Int
    let market: Market
    /// Symbol used when subscribing on the Hyperliquid public websocket (e.g. "BTC").
    let hyperliquidSymbol: String

    var symbolName: String {
        switch market {
        case .crypto:
            "bitcoinsign.circle.fill"
        }
    }
}

extension CoinInfo {
    enum Market: String, Codable, Sendable {
        case crypto = "Crypto"
    }

    static let bitcoin = CoinInfo(
        id: "BTCUSDT",
        symbol: "BTC/USDT",
        name: "Bitcoin/Tether",
        nameid: "bitcoin-tether",
        rank: 1,
        market: .crypto,
        hyperliquidSymbol: "BTC"
    )

    static let ethereum = CoinInfo(
        id: "ETHUSDT",
        symbol: "ETH/USDT",
        name: "Ethereum/Tether",
        nameid: "ethereum-tether",
        rank: 2,
        market: .crypto,
        hyperliquidSymbol: "ETH"
    )

    static let solana = CoinInfo(
        id: "SOLUSDT",
        symbol: "SOL/USDT",
        name: "Solana/Tether",
        nameid: "solana-tether",
        rank: 3,
        market: .crypto,
        hyperliquidSymbol: "SOL"
    )

    /// The full catalog offered by the app. Hyperliquid is the only data source.
    static let supportedSymbols: [CoinInfo] = [
        .bitcoin,
        .ethereum,
        .solana
    ]
}
