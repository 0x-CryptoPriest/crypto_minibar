import Foundation

extension CoinInfo {
    /// Builds a ticker from a single live trade. Percent changes are computed
    /// separately in the view model from a historical baseline, so the stream
    /// only needs to carry the current price.
    func liveTicker(price: Decimal, date: Date, volume24: Decimal?) -> BTCTicker {
        BTCTicker(
            id: id,
            symbol: symbol,
            name: name,
            nameid: nameid,
            rank: rank,
            date: date,
            price: price,
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

extension Decimal {
    /// Parses a price/quantity string from an exchange feed using a fixed POSIX
    /// locale so decimal separators never depend on the user's region.
    init?(exchangeString string: String) {
        guard let value = Decimal(string: string, locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }
        self = value
    }
}

extension Date {
    /// Builds a date from an exchange epoch timestamp expressed in milliseconds.
    init(exchangeMilliseconds milliseconds: Double) {
        self.init(timeIntervalSince1970: milliseconds / 1_000)
    }
}

/// Error surface for the public exchange websocket feed.
enum ExchangeFeedError: LocalizedError {
    case encodingFailed(exchange: String)
    case unsupportedSymbol(exchange: String, symbol: String)
    case staleConnection(exchange: String)

    var errorDescription: String? {
        switch self {
        case .encodingFailed(let exchange):
            "Failed to encode \(exchange) websocket request."
        case .unsupportedSymbol(let exchange, let symbol):
            "\(exchange) public websocket does not expose \(symbol) in this build."
        case .staleConnection(let exchange):
            "\(exchange) websocket stalled; reconnecting."
        }
    }
}
