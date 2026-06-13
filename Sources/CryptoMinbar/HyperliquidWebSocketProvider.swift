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
            // `symbol` is the Hyperliquid coin name (e.g. "BTC", "kPEPE").
            guard let url = URL(string: "wss://api.hyperliquid.xyz/ws") else {
                continuation.finish(throwing: ExchangeFeedError.unsupportedSymbol(exchange: "Hyperliquid", symbol: symbol))
                return
            }

            let coin = CoinInfo.hyperliquid(symbol)
            let streamSymbol = symbol
            let webSocket = session.webSocketTask(with: url)
            let task = Task {
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
                        continuation.yield(coin.liveTicker(price: tick.price, date: tick.date, volume24: nil))
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
