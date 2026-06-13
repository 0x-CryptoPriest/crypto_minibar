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

    /// Builds a coin from a Hyperliquid universe name (the identity used for
    /// subscribing, fetching candles, persistence, and display).
    static func hyperliquid(_ name: String) -> CoinInfo {
        CoinInfo(
            id: name,
            symbol: name,
            name: name,
            nameid: name.lowercased(),
            rank: 0,
            market: .crypto,
            hyperliquidSymbol: name
        )
    }

    /// Built-in fallback shown before the full universe loads (and offline).
    static let defaultSymbols: [CoinInfo] = ["BTC", "ETH", "SOL"].map(CoinInfo.hyperliquid)
}
