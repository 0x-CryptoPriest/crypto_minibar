import Foundation

struct BinanceWebSocketProvider: TickerStreamProvider {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func streamTicker(token: String, symbol: String) -> AsyncThrowingStream<BTCTicker, Error> {
        AsyncThrowingStream { continuation in
            guard let coin = StandardFeedProvider.binance.supportedCoins.first(where: { $0.id == symbol }),
                  let streamSymbol = StandardFeedProvider.binance.streamSymbol(for: coin) else {
                continuation.finish(throwing: BinanceFeedError.unsupportedSymbol(symbol))
                return
            }

            let url = URL(string: "wss://data-stream.binance.vision/ws/\(streamSymbol.lowercased())@trade")!
            let webSocket = session.webSocketTask(with: url)
            let task = Task {
                var history = PriceHistory()
                webSocket.resume()

                do {
                    defer {
                        webSocket.cancel(with: .goingAway, reason: nil)
                    }

                    while !Task.isCancelled {
                        let message = try await webSocket.receive()
                        guard let text = message.textValue,
                              let trade = try decodeTrade(from: text, expectedSymbol: streamSymbol) else {
                            continue
                        }
                        history = history.appending(price: trade.price, at: trade.date)
                        continuation.yield(coin.liveTicker(
                            price: trade.price,
                            date: trade.date,
                            history: history,
                            volume24: nil
                        ))
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
                webSocket.cancel(with: .goingAway, reason: nil)
            }
        }
    }

    private func decodeTrade(from text: String, expectedSymbol: String) throws -> BinanceTrade? {
        let message = try JSONDecoder().decode(BinanceTradeMessage.self, from: Data(text.utf8))
        guard message.event == "trade",
              message.symbol == expectedSymbol,
              let price = Decimal(string: message.price, locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }
        let date = Date(timeIntervalSince1970: TimeInterval(message.tradeTime) / 1_000)
        return BinanceTrade(price: price, date: date)
    }
}

private struct BinanceTradeMessage: Decodable {
    let event: String
    let symbol: String
    let price: String
    let tradeTime: Int64

    enum CodingKeys: String, CodingKey {
        case event = "e"
        case symbol = "s"
        case price = "p"
        case tradeTime = "T"
    }
}

private struct BinanceTrade: Sendable {
    let price: Decimal
    let date: Date
}

enum BinanceFeedError: LocalizedError {
    case unsupportedSymbol(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedSymbol(let symbol):
            "Binance public websocket does not expose \(symbol) in this build."
        }
    }
}
