import Foundation

protocol TickerStreamProvider: Sendable {
    func streamTicker(token: String, symbol: String) -> AsyncThrowingStream<BTCTicker, Error>
}

struct AllTickWebSocketProvider: TickerStreamProvider {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func streamTicker(token: String, symbol: String) -> AsyncThrowingStream<BTCTicker, Error> {
        AsyncThrowingStream { continuation in
            guard let coin = CoinInfo.allTickSymbols.first(where: { $0.id == symbol }) else {
                continuation.finish(throwing: AllTickError.unknownSymbol(symbol))
                return
            }
            let url = coin.quoteEndpoint.url.appending(queryItems: [URLQueryItem(name: "token", value: token)])
            let webSocket = session.webSocketTask(with: url)
            let task = Task {
                var history = PriceHistory()
                let sequence = AllTickSequence()
                webSocket.resume()

                do {
                    let subscriptionSequence = await sequence.next()
                    try await sendSubscription(webSocket: webSocket, sequence: subscriptionSequence, symbol: symbol)
                    let heartbeatTask = Task {
                        while !Task.isCancelled {
                            try? await Task.sleep(for: .seconds(10))
                            let nextSequence = await sequence.next()
                            try? await sendHeartbeat(webSocket: webSocket, sequence: nextSequence)
                        }
                    }
                    defer {
                        heartbeatTask.cancel()
                        webSocket.cancel(with: .goingAway, reason: nil)
                    }

                    while !Task.isCancelled {
                        let message = try await webSocket.receive()
                        guard let text = message.textValue,
                              let tick = try decodeTick(from: text, symbol: symbol) else {
                            continue
                        }
                        let date = tick.date
                        history = history.appending(price: tick.price, at: date)
                        continuation.yield(BTCTicker(
                            id: coin.id,
                            symbol: coin.symbol,
                            name: coin.name,
                            nameid: coin.nameid,
                            rank: coin.rank,
                            date: date,
                            price: tick.price,
                            percentChange5m: history.percentChange(minutes: 5, currentPrice: tick.price, at: date),
                            percentChange15m: history.percentChange(minutes: 15, currentPrice: tick.price, at: date),
                            marketCapUSD: nil,
                            volume24: tick.volume
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

    private func sendSubscription(webSocket: URLSessionWebSocketTask, sequence: Int, symbol: String) async throws {
        let request = AllTickRequest(
            cmdID: 22_004,
            seqID: sequence,
            trace: UUID().uuidString,
            data: AllTickSubscriptionData(symbolList: [AllTickSymbol(code: symbol)])
        )
        let data = try JSONEncoder().encode(request)
        guard let text = String(data: data, encoding: .utf8) else {
            throw AllTickError.encodingFailed
        }
        try await webSocket.send(.string(text))
    }

    private func sendHeartbeat(webSocket: URLSessionWebSocketTask, sequence: Int) async throws {
        let request = AllTickHeartbeatRequest(cmdID: 22_000, seqID: sequence, trace: UUID().uuidString, data: [:])
        let data = try JSONEncoder().encode(request)
        guard let text = String(data: data, encoding: .utf8) else {
            throw AllTickError.encodingFailed
        }
        try await webSocket.send(.string(text))
    }

    private func decodeTick(from text: String, symbol: String) throws -> AllTickTick? {
        let message = try JSONDecoder().decode(AllTickMessage.self, from: Data(text.utf8))
        guard message.cmdID == 22_998,
              let data = message.data,
              data.code == symbol,
              let price = Decimal(string: data.price, locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }
        let volume = data.volume.flatMap { Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX")) }
        let date = data.tickTime.flatMap(Self.date(from:)) ?? Date()
        return AllTickTick(price: price, volume: volume, date: date)
    }

    private static func date(from tickTime: String) -> Date? {
        guard let raw = Double(tickTime) else {
            return nil
        }
        let seconds = raw > 10_000_000_000 ? raw / 1_000 : raw
        return Date(timeIntervalSince1970: seconds)
    }
}

private actor AllTickSequence {
    private var value = 1

    func next() -> Int {
        let current = value
        value += 1
        return current
    }
}

private extension URLSessionWebSocketTask.Message {
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

private struct AllTickRequest: Encodable {
    let cmdID: Int
    let seqID: Int
    let trace: String
    let data: AllTickSubscriptionData

    enum CodingKeys: String, CodingKey {
        case cmdID = "cmd_id"
        case seqID = "seq_id"
        case trace
        case data
    }
}

private struct AllTickHeartbeatRequest: Encodable {
    let cmdID: Int
    let seqID: Int
    let trace: String
    let data: [String: String]

    enum CodingKeys: String, CodingKey {
        case cmdID = "cmd_id"
        case seqID = "seq_id"
        case trace
        case data
    }
}

private struct AllTickSubscriptionData: Encodable {
    let symbolList: [AllTickSymbol]

    enum CodingKeys: String, CodingKey {
        case symbolList = "symbol_list"
    }
}

private struct AllTickSymbol: Encodable {
    let code: String
}

private struct AllTickMessage: Decodable {
    let cmdID: Int
    let data: AllTickTickData?

    enum CodingKeys: String, CodingKey {
        case cmdID = "cmd_id"
        case data
    }
}

private struct AllTickTickData: Decodable {
    let code: String
    let tickTime: String?
    let price: String
    let volume: String?

    enum CodingKeys: String, CodingKey {
        case code
        case tickTime = "tick_time"
        case price
        case volume
    }
}

private struct AllTickTick: Equatable, Sendable {
    let price: Decimal
    let volume: Decimal?
    let date: Date
}

enum AllTickError: LocalizedError {
    case encodingFailed
    case unknownSymbol(String)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            "Failed to encode AllTick websocket request."
        case .unknownSymbol(let symbol):
            "Unknown AllTick symbol: \(symbol)"
        }
    }
}
