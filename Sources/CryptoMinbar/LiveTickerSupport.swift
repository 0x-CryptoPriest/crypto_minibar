import Foundation

extension CoinInfo {
    func liveTicker(
        price: Decimal,
        date: Date,
        history: PriceHistory,
        volume24: Decimal?
    ) -> BTCTicker {
        BTCTicker(
            id: id,
            symbol: symbol,
            name: name,
            nameid: nameid,
            rank: rank,
            date: date,
            price: price,
            percentChange5m: history.percentChange(minutes: 5, currentPrice: price, at: date),
            percentChange15m: history.percentChange(minutes: 15, currentPrice: price, at: date),
            marketCapUSD: nil,
            volume24: volume24
        )
    }
}

extension URLSessionWebSocketTask.Message {
    var textValue: String? {
        switch self {
        case .string(let text):
            text
        case .data(let data):
            String(data: data, encoding: .utf8)
        @unknown default:
            nil
        }
    }
}
