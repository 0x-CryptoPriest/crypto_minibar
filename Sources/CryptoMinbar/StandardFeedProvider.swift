import Foundation

enum StandardFeedProvider: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case allTick
    case binance
    case okx
    case hyperliquid

    var id: String { rawValue }

    var label: String {
        switch self {
        case .allTick:
            "AllTick"
        case .binance:
            "Binance"
        case .okx:
            "OKX"
        case .hyperliquid:
            "Hyperliquid"
        }
    }

    var sourceLabel: String {
        switch self {
        case .allTick:
            "Standard · AllTick"
        case .binance:
            "Standard · Binance"
        case .okx:
            "Standard · OKX"
        case .hyperliquid:
            "Standard · Hyperliquid"
        }
    }

    var requiresToken: Bool {
        switch self {
        case .allTick:
            true
        case .binance, .okx, .hyperliquid:
            false
        }
    }

    var supportedCoins: [CoinInfo] {
        switch self {
        case .allTick:
            CoinInfo.allTickSymbols
        case .binance, .okx, .hyperliquid:
            CoinInfo.exchangeSymbols
        }
    }

    func streamSymbol(for coin: CoinInfo) -> String? {
        switch self {
        case .allTick, .binance:
            coin.id
        case .okx:
            switch coin.id {
            case "BTCUSDT":
                "BTC-USDT"
            case "ETHUSDT":
                "ETH-USDT"
            case "SOLUSDT":
                "SOL-USDT"
            default:
                nil
            }
        case .hyperliquid:
            switch coin.id {
            case "BTCUSDT":
                "BTC"
            case "ETHUSDT":
                "ETH"
            case "SOLUSDT":
                "SOL"
            default:
                nil
            }
        }
    }
}
