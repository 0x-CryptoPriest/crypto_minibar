import Foundation

protocol TickerStreamProvider: Sendable {
    func streamTicker(symbol: String) -> AsyncThrowingStream<BTCTicker, Error>
}

struct HyperliquidWebSocketProvider: TickerStreamProvider {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func streamTicker(symbol: String) -> AsyncThrowingStream<BTCTicker, Error> {
        AsyncThrowingStream { continuation in
            guard let coin = CoinInfo.supportedSymbols.first(where: { $0.id == symbol }),
                  let url = URL(string: "wss://api.hyperliquid.xyz/ws") else {
                continuation.finish(throwing: ExchangeFeedError.unsupportedSymbol(exchange: "Hyperliquid", symbol: symbol))
                return
            }

            let streamSymbol = coin.hyperliquidSymbol
            let webSocket = session.webSocketTask(with: url)
            let task = Task {
                var history = PriceHistory()
                webSocket.resume()

                do {
                    defer {
                        webSocket.cancel(with: .goingAway, reason: nil)
                    }

                    try await subscribe(webSocket: webSocket, streamSymbol: streamSymbol)

                    while !Task.isCancelled {
                        let message = try await webSocket.receive()
                        guard let text = message.textValue,
                              let tick = try decodeTrade(from: text, expectedSymbol: streamSymbol) else {
                            continue
                        }
                        history = history.appending(price: tick.price, at: tick.date)
                        continuation.yield(coin.liveTicker(
                            price: tick.price,
                            date: tick.date,
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

    private func subscribe(webSocket: URLSessionWebSocketTask, streamSymbol: String) async throws {
        let payload = HyperliquidSubscribeMessage(
            method: "subscribe",
            subscription: .init(type: "trades", coin: streamSymbol)
        )
        let data = try JSONEncoder().encode(payload)
        guard let text = String(data: data, encoding: .utf8) else {
            throw ExchangeFeedError.encodingFailed(exchange: "Hyperliquid")
        }
        try await webSocket.send(.string(text))
    }

    private func decodeTrade(from text: String, expectedSymbol: String) throws -> HyperliquidTrade? {
        try HyperliquidTradeDecoder.decodeTrade(from: text, expectedSymbol: expectedSymbol)
    }
}

enum HyperliquidTradeDecoder {
    private static let decoder = JSONDecoder()

    static func decodeTrade(from text: String, expectedSymbol: String) throws -> HyperliquidTrade? {
        let data = Data(text.utf8)
        // Decode the channel first so non-trade frames (e.g. subscription
        // acknowledgements, whose `data` is an object not an array) are skipped
        // before attempting the stricter trade decode.
        let envelope = try decoder.decode(HyperliquidEnvelope.self, from: data)
        guard envelope.channel == "trades" else {
            return nil
        }

        let message = try decoder.decode(HyperliquidTradesMessage.self, from: data)
        guard let trade = message.data.first,
              trade.coin == expectedSymbol,
              let price = Decimal(exchangeString: trade.price) else {
            return nil
        }

        return HyperliquidTrade(price: price, date: Date(exchangeMilliseconds: Double(trade.time)))
    }
}

private struct HyperliquidSubscribeMessage: Encodable {
    let method: String
    let subscription: HyperliquidSubscription
}

private struct HyperliquidSubscription: Encodable {
    let type: String
    let coin: String
}

private struct HyperliquidEnvelope: Decodable {
    let channel: String?
}

private struct HyperliquidTradesMessage: Decodable {
    let channel: String
    let data: [HyperliquidTradeData]
}

private struct HyperliquidTradeData: Decodable {
    let coin: String
    let price: String
    let time: Int64

    enum CodingKeys: String, CodingKey {
        case coin
        case price = "px"
        case time
    }
}

struct HyperliquidTrade: Equatable, Sendable {
    let price: Decimal
    let date: Date
}
