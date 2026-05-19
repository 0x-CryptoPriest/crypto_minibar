import Foundation

struct CoinInfo: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let symbol: String
    let name: String
    let nameid: String
    let rank: Int

    var symbolName: String {
        switch symbol {
        case "BTC": return "bitcoinsign.circle.fill"
        case "LINK": return "link.circle.fill"
        default:
            let letter = symbol.prefix(1).lowercased()
            return "\(letter).circle.fill"
        }
    }
}

extension CoinInfo {
    static let bitcoin = CoinInfo(id: "BTCUSDT", symbol: "BTC", name: "Bitcoin", nameid: "bitcoin", rank: 1)

    static let allTickSymbols: [CoinInfo] = [
        .bitcoin,
        CoinInfo(id: "ETHUSDT", symbol: "ETH", name: "Ethereum", nameid: "ethereum", rank: 2),
        CoinInfo(id: "XRPUSDT", symbol: "XRP", name: "XRP", nameid: "xrp", rank: 3),
        CoinInfo(id: "BNBUSDT", symbol: "BNB", name: "BNB", nameid: "bnb", rank: 4),
        CoinInfo(id: "SOLUSDT", symbol: "SOL", name: "Solana", nameid: "solana", rank: 5),
        CoinInfo(id: "DOGEUSDT", symbol: "DOGE", name: "Dogecoin", nameid: "dogecoin", rank: 6),
    ]
}
