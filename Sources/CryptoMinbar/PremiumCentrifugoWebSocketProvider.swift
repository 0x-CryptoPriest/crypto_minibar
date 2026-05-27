import Foundation
import SwiftCentrifuge

struct PremiumCentrifugoWebSocketProvider: TickerStreamProvider {
    private let feedURL: URL
    private let session: URLSession

    init(feedURL: URL, session: URLSession = .shared) {
        self.feedURL = feedURL
        self.session = session
    }

    func streamTicker(token userToken: String, symbol: String) -> AsyncThrowingStream<BTCTicker, Error> {
        AsyncThrowingStream { continuation in
            guard let coin = CoinInfo.premiumSymbols.first(where: { $0.id == symbol }) else {
                continuation.finish(throwing: PremiumFeedError.unsupportedSymbol(symbol))
                return
            }

            guard let exchangeURL = Self.exchangeURL(for: feedURL) else {
                continuation.finish(throwing: PremiumFeedError.invalidFeedURL(feedURL.absoluteString))
                return
            }

            let box = PremiumCentrifugoConnectionBox()
            let delegate = PremiumCentrifugoDelegate(
                coin: coin,
                expectedSymbol: symbol,
                continuation: continuation
            )

            let tokenGetter: CentrifugeConnectionTokenGetter = { _, completion in
                exchangeToken(
                    userToken: userToken,
                    exchangeURL: exchangeURL,
                    session: session
                ) { result in
                    switch result {
                    case .success(let response):
                        completion(.success(response.centrifugoToken))
                    case .failure(PremiumFeedError.unauthorized):
                        completion(.failure(CentrifugeError.unauthorized))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            }

            let config = CentrifugeClientConfig(
                maxReconnectDelay: 30,
                useNativeWebSocket: true,
                tokenGetter: tokenGetter
            )
            let client = CentrifugeClient(
                endpoint: feedURL.absoluteString,
                config: config,
                delegate: delegate
            )

            box.set(client: client, delegate: delegate)
            continuation.onTermination = { @Sendable _ in
                box.disconnect()
            }
            client.connect()
        }
    }

    private static func exchangeURL(for feedURL: URL) -> URL? {
        guard var components = URLComponents(url: feedURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        switch components.scheme?.lowercased() {
        case "wss":
            components.scheme = "https"
        case "ws":
            components.scheme = "http"
        case "https", "http":
            break
        default:
            return nil
        }
        components.path = "/auth/exchange"
        components.query = nil
        components.fragment = nil
        return components.url
    }
}

private func exchangeToken(
    userToken: String,
    exchangeURL: URL,
    session: URLSession,
    completion: @escaping (Result<PremiumExchangeResponse, Error>) -> Void
) {
    var request = URLRequest(url: exchangeURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    do {
        request.httpBody = try JSONEncoder().encode(PremiumExchangeRequest(token: userToken))
    } catch {
        completion(.failure(error))
        return
    }

    let completionBox = ExchangeCompletionBox(completion)
    let task = session.dataTask(with: request) { data, response, error in
        if let error {
            completionBox.complete(.failure(error))
            return
        }
        do {
            completionBox.complete(.success(try decodeExchangeResponse(data: data, response: response)))
        } catch {
            completionBox.complete(.failure(error))
        }
    }
    task.resume()
}

private final class ExchangeCompletionBox: @unchecked Sendable {
    private let lock = NSLock()
    private var completion: ((Result<PremiumExchangeResponse, Error>) -> Void)?

    init(_ completion: @escaping (Result<PremiumExchangeResponse, Error>) -> Void) {
        self.completion = completion
    }

    func complete(_ result: Result<PremiumExchangeResponse, Error>) {
        lock.lock()
        let completion = completion
        self.completion = nil
        lock.unlock()
        completion?(result)
    }
}

private func decodeExchangeResponse(data: Data?, response: URLResponse?) throws -> PremiumExchangeResponse {
    let data = data ?? Data()
    guard let httpResponse = response as? HTTPURLResponse else {
        throw PremiumFeedError.invalidExchangeResponse
    }

    guard (200..<300).contains(httpResponse.statusCode) else {
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw PremiumFeedError.unauthorized
        }
        let message = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        throw PremiumFeedError.exchangeRejected(statusCode: httpResponse.statusCode, message: message)
    }

    let decoded = try JSONDecoder().decode(PremiumExchangeResponse.self, from: data)
    guard !decoded.centrifugoToken.isEmpty else {
        throw PremiumFeedError.invalidExchangeResponse
    }
    return decoded
}

private final class PremiumCentrifugoConnectionBox: @unchecked Sendable {
    private let lock = NSLock()
    private var client: CentrifugeClient?
    private var delegate: PremiumCentrifugoDelegate?

    func set(client: CentrifugeClient, delegate: PremiumCentrifugoDelegate) {
        lock.lock()
        self.client = client
        self.delegate = delegate
        lock.unlock()
    }

    func disconnect() {
        lock.lock()
        let client = self.client
        self.client = nil
        self.delegate = nil
        lock.unlock()

        client?.disconnect()
    }
}

private final class PremiumCentrifugoDelegate: CentrifugeClientDelegate {
    private let coin: CoinInfo
    private let expectedSymbol: String
    private let continuation: AsyncThrowingStream<BTCTicker, Error>.Continuation
    private let lock = NSLock()
    private var history = PriceHistory()
    private var isFinished = false

    init(
        coin: CoinInfo,
        expectedSymbol: String,
        continuation: AsyncThrowingStream<BTCTicker, Error>.Continuation
    ) {
        self.coin = coin
        self.expectedSymbol = expectedSymbol
        self.continuation = continuation
    }

    func onPublication(_ client: CentrifugeClient, _ event: CentrifugeServerPublicationEvent) {
        do {
            guard let tick = try decodeTick(from: event.data), tick.symbol == expectedSymbol else {
                return
            }

            lock.lock()
            history = history.appending(price: tick.price, at: tick.date)
            let currentHistory = history
            lock.unlock()

            continuation.yield(coin.liveTicker(
                price: tick.price,
                date: tick.date,
                history: currentHistory,
                volume24: tick.volume
            ))
        } catch {
            finish(throwing: error)
        }
    }

    func onError(_ client: CentrifugeClient, _ event: CentrifugeErrorEvent) {
        guard let error = event.error as? CentrifugeError else {
            return
        }
        switch error {
        case .unauthorized, .tokenError:
            finish(throwing: PremiumFeedError.unauthorized)
        default:
            break
        }
    }

    private func finish(throwing error: Error) {
        lock.lock()
        defer { lock.unlock() }
        guard !isFinished else { return }
        isFinished = true
        continuation.finish(throwing: error)
    }

    private func decodeTick(from data: Data) throws -> PremiumFeedTick? {
        let message = try JSONDecoder().decode(PremiumFeedMessage.self, from: data)
        guard message.symbol == expectedSymbol,
              let price = Decimal(string: message.price, locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }

        let volume = message.volume.flatMap {
            Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX"))
        }
        let date = Self.date(from: message.tickTime)
            ?? Self.date(from: message.receivedAt)
            ?? Date()
        return PremiumFeedTick(symbol: message.symbol, price: price, volume: volume, date: date)
    }

    private static func date(from raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let formatterWithFractions = ISO8601DateFormatter()
        formatterWithFractions.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatterWithFractions.date(from: raw) {
            return date
        }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: raw) {
            return date
        }
        if let seconds = Double(raw) {
            return Date(timeIntervalSince1970: seconds > 10_000_000_000 ? seconds / 1000 : seconds)
        }
        return nil
    }
}

private struct PremiumExchangeRequest: Encodable {
    let token: String
}

private struct PremiumExchangeResponse: Decodable {
    let centrifugoToken: String
    let channels: [String]
    let expiresAt: String
    let websocketURL: String

    enum CodingKeys: String, CodingKey {
        case centrifugoToken = "centrifugo_token"
        case channels
        case expiresAt = "expires_at"
        case websocketURL = "websocket_url"
    }
}

private struct PremiumFeedMessage: Decodable {
    let symbol: String
    let price: String
    let tickTime: String?
    let receivedAt: String?
    let volume: String?

    enum CodingKeys: String, CodingKey {
        case symbol
        case price
        case tickTime = "tick_time"
        case receivedAt = "received_at"
        case volume
    }
}

private struct PremiumFeedTick: Sendable {
    let symbol: String
    let price: Decimal
    let volume: Decimal?
    let date: Date
}

enum PremiumFeedError: LocalizedError {
    case invalidFeedURL(String)
    case unsupportedSymbol(String)
    case invalidExchangeResponse
    case exchangeRejected(statusCode: Int, message: String?)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidFeedURL(let url):
            "Invalid premium feed URL: \(url)"
        case .unsupportedSymbol(let symbol):
            "Premium feed does not expose \(symbol) yet."
        case .invalidExchangeResponse:
            "Premium token issuer returned an invalid response."
        case .exchangeRejected(let statusCode, let message):
            if let message, !message.isEmpty {
                "Premium token exchange failed (\(statusCode)): \(message)"
            } else {
                "Premium token exchange failed with HTTP \(statusCode)."
            }
        case .unauthorized:
            "Premium token is invalid, expired, or disabled."
        }
    }
}
