import AppKit
import Combine
import Foundation
import ServiceManagement
import UserNotifications

@MainActor
final class TickerViewModel: ObservableObject {
    @Published private(set) var ticker: BTCTicker?
    @Published private(set) var coins: [CoinInfo] = CoinInfo.defaultSymbols
    @Published private(set) var selectedCoin: CoinInfo = CoinInfo.defaultSymbols[0]
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var errorMessage: String?
    @Published private(set) var connectionState: ConnectionState = .connecting
    @Published var isShowingSettings = false
    @Published private(set) var notificationStatusText = "Checking notifications..."
    @Published private(set) var primaryWindow: ChangeWindow = .h1
    @Published private(set) var secondaryWindow: ChangeWindow = .h24
    @Published private(set) var primaryChange: Decimal?
    @Published private(set) var secondaryChange: Decimal?
    /// 24h of 5-minute candles backing the popover sparkline (same data as the
    /// change baseline; reused so the chart costs no extra network).
    @Published private(set) var chartCandles: [PriceCandle] = []
    @Published var alerts: [PriceAlert] {
        didSet { saveAlerts() }
    }
    @Published var showChangeInBar: Bool {
        didSet { UserDefaults.standard.set(showChangeInBar, forKey: "showChangeInBar") }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            guard !isUpdatingLaunchAtLogin else { return }
            guard launchAtLogin != oldValue else { return }
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                isUpdatingLaunchAtLogin = true
                launchAtLogin = oldValue
                isUpdatingLaunchAtLogin = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private let streamProvider: any TickerStreamProvider
    private let candleService: any CandleProviding
    private let catalogService: any CoinCatalogProviding
    private var streamTask: Task<Void, Never>?
    private var connectionSetupTask: Task<Void, Never>?
    private var connectionRequestVersion = 0
    private var streamFailureCount = 0
    private var catalogTask: Task<Void, Never>?
    private var isUpdatingLaunchAtLogin = false
    private var baseline = PriceBaseline()
    private var baselineCoinID: String?
    private var lastBaselineFetch: Date?
    private var baselineTask: Task<Void, Never>?
    private let tickSubject = PassthroughSubject<BTCTicker, Never>()
    private var cancellables = Set<AnyCancellable>()

    init(
        streamProvider: any TickerStreamProvider = HyperliquidWebSocketProvider(),
        candleService: any CandleProviding = HyperliquidCandleService(),
        catalogService: any CoinCatalogProviding = HyperliquidMetaService()
    ) {
        self.streamProvider = streamProvider
        self.candleService = candleService
        self.catalogService = catalogService
        self.showChangeInBar = UserDefaults.standard.bool(forKey: "showChangeInBar")
        self.alerts = Self.loadAlerts()
        let initialCoins = Self.cachedCatalog() ?? CoinInfo.defaultSymbols
        self.coins = initialCoins
        self.selectedCoin = Self.storedCoin(in: initialCoins)
        self.primaryWindow = Self.storedWindow(forKey: Self.primaryWindowKey, default: .h1)
        self.secondaryWindow = Self.storedWindow(forKey: Self.secondaryWindowKey, default: .h24)
        self.launchAtLogin = SMAppService.mainApp.status == .enabled

        // Apply incoming ticks to UI state at most ~5x/sec (alerts still run on
        // every raw tick in the stream loop, so no threshold crossing is missed).
        tickSubject
            .throttle(for: .milliseconds(200), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] tick in
                self?.applyTick(tick)
            }
            .store(in: &cancellables)
    }

    deinit {
        streamTask?.cancel()
        baselineTask?.cancel()
    }

    var statusTitle: String {
        guard let ticker else { return "\(selectedCoin.symbol) --" }
        let price = "$\(DisplayFormatters.priceString(ticker.price))"
        guard showChangeInBar, let change = primaryChange else {
            return "\(ticker.symbol) \(price)"
        }
        // `DisplayFormatters.percent` already prefixes "+" for non-negative
        // values, so no manual sign is added here (that produced "++0.42%").
        return "\(ticker.symbol) \(price) \(DisplayFormatters.percentString(change))%"
    }

    var feedSourceLabel: String { "Hyperliquid" }

    /// The large headline price shown in the popover, formatted as USD currency.
    var heroPriceText: String {
        guard let ticker else { return "$ —" }
        return "$\(DisplayFormatters.priceString(ticker.price))"
    }

    func start() {
        if Self.canUseUserNotifications {
            Task { [weak self] in
                await self?.refreshNotificationStatus()
            }
        } else {
            notificationStatusText = "Notifications unavailable"
        }
        requestConnect()
        refreshBaseline(force: true)
        loadCatalog()
    }

    func stop() {
        connectionRequestVersion += 1
        connectionSetupTask?.cancel()
        connectionSetupTask = nil
        streamTask?.cancel()
        streamTask = nil
        baselineTask?.cancel()
        baselineTask = nil
        catalogTask?.cancel()
        catalogTask = nil
    }

    /// Loads the full tradeable Hyperliquid universe to populate the coin picker.
    private func loadCatalog() {
        catalogTask?.cancel()
        let service = catalogService
        catalogTask = Task { [weak self] in
            guard let names = try? await service.coins(), !names.isEmpty else { return }
            guard let self, !Task.isCancelled else { return }
            self.coins = names.map(CoinInfo.hyperliquid)
            UserDefaults.standard.set(names, forKey: Self.catalogCacheKey)
        }
    }

    private static func cachedCatalog() -> [CoinInfo]? {
        guard let names = UserDefaults.standard.stringArray(forKey: catalogCacheKey), !names.isEmpty else {
            return nil
        }
        return names.map(CoinInfo.hyperliquid)
    }

    func selectCoin(id: String) {
        guard let coin = coins.first(where: { $0.id == id }) else {
            return
        }
        selectCoin(coin)
    }

    func selectCoin(_ coin: CoinInfo) {
        guard coin.id != selectedCoin.id else {
            return
        }
        selectedCoin = coin
        ticker = nil
        lastUpdated = nil
        errorMessage = nil
        primaryChange = nil
        secondaryChange = nil
        chartCandles = []
        baseline = PriceBaseline()
        baselineCoinID = nil
        UserDefaults.standard.set(coin.id, forKey: Self.selectedCoinIDKey)
        requestConnect()
        refreshBaseline(force: true)
    }

    func selectPrimaryWindow(_ window: ChangeWindow) {
        guard window != primaryWindow else { return }
        primaryWindow = window
        UserDefaults.standard.set(window.rawValue, forKey: Self.primaryWindowKey)
        recomputeChanges()
    }

    func selectSecondaryWindow(_ window: ChangeWindow) {
        guard window != secondaryWindow else { return }
        secondaryWindow = window
        UserDefaults.standard.set(window.rawValue, forKey: Self.secondaryWindowKey)
        recomputeChanges()
    }

    func refreshNow() async {
        requestConnect()
        refreshBaseline(force: true)
    }

    func copyPriceToClipboard() {
        guard ticker != nil else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(statusTitle, forType: .string)
    }

    func toggleSettings() {
        isShowingSettings.toggle()
    }

    func requestNotificationPermission() {
        guard Self.canUseUserNotifications else {
            notificationStatusText = "Notifications unavailable"
            return
        }
        notificationStatusText = "Checking notifications..."
        Task { [weak self] in
            guard let self else { return }
            let authorizationStatus = await Self.currentNotificationAuthorizationStatus()
            switch authorizationStatus {
            case .notDetermined:
                do {
                    let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                    await self.refreshNotificationStatus()
                    if granted {
                        self.sendTestNotification()
                    }
                } catch {
                    self.notificationStatusText = "Notification failed"
                    self.errorMessage = error.localizedDescription
                }
            case .denied:
                self.notificationStatusText = "Notifications blocked"
                self.openNotificationSettings()
            case .authorized, .provisional, .ephemeral:
                await self.refreshNotificationStatus()
                self.sendTestNotification()
            @unknown default:
                await self.refreshNotificationStatus()
            }
        }
    }

    func sendTestNotification() {
        guard Self.canUseUserNotifications else {
            notificationStatusText = "Notifications unavailable"
            return
        }
        notificationStatusText = "Sending test notification..."
        let content = UNMutableNotificationContent()
        content.title = "MiniC"
        content.body = "Notifications are ready."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "notification-test-\(UUID().uuidString)", content: content, trigger: nil)
        Task { [weak self] in
            guard let self else { return }
            do {
                try await UNUserNotificationCenter.current().add(request)
                self.notificationStatusText = "Test notification sent"
            } catch {
                self.notificationStatusText = "Notification failed"
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func refreshNotificationStatus() async {
        guard Self.canUseUserNotifications else {
            notificationStatusText = "Notifications unavailable"
            return
        }
        let authorizationStatus = await Self.currentNotificationAuthorizationStatus()
        notificationStatusText = Self.notificationStatusText(for: authorizationStatus)
    }

    func openNotificationSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.notifications"
        ]

        for rawURL in urls {
            guard let url = URL(string: rawURL) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }

        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: "/System/Applications/System Settings.app"),
            configuration: NSWorkspace.OpenConfiguration()
        )
    }

    func addAlert(threshold: Decimal, direction: PriceAlert.Direction) {
        alerts.append(PriceAlert(
            symbol: selectedCoin.id,
            threshold: threshold,
            direction: direction
        ))
    }

    func deleteAlert(_ alert: PriceAlert) {
        alerts.removeAll { $0.id == alert.id }
    }

    func resetAlert(_ alert: PriceAlert) {
        guard let index = alerts.firstIndex(where: { $0.id == alert.id }) else {
            return
        }
        alerts[index].isTriggered = false
    }

    private func requestConnect() {
        connectionRequestVersion += 1
        let version = connectionRequestVersion
        let symbol = selectedCoin.id
        let previousTask = connectionSetupTask
        connectionSetupTask = Task { [weak self] in
            await previousTask?.value
            guard let self else { return }
            guard !Task.isCancelled else { return }
            await self.connect(symbol: symbol, version: version)
        }
    }

    private func connect(symbol: String, version: Int) async {
        await stopCurrentStream()
        guard connectionRequestVersion == version, selectedCoin.id == symbol, !Task.isCancelled else {
            return
        }
        startStream(symbol: symbol)
    }

    private func stopCurrentStream() async {
        let previousTask = streamTask
        streamTask = nil
        previousTask?.cancel()
        if let previousTask {
            await previousTask.value
        }
    }

    /// Applies a throttled tick to UI state. Guards against a late tick from a
    /// previously-selected coin arriving after a switch.
    private func applyTick(_ tick: BTCTicker) {
        guard tick.id == selectedCoin.id else { return }
        ticker = tick
        lastUpdated = Date()
        connectionState = .live
        streamFailureCount = 0
        errorMessage = nil
        recomputeChanges()
        refreshBaseline(force: false)
    }

    /// A stream end/error: pulse yellow while retrying, turn red after repeated
    /// failures so the dot distinguishes "reconnecting" from "can't connect".
    private func registerStreamInterruption() {
        streamFailureCount += 1
        connectionState = streamFailureCount >= Self.offlineThreshold ? .offline : .reconnecting
    }

    private func recomputeChanges() {
        let now = Date()
        let price = ticker?.price
        primaryChange = price.flatMap { baseline.change(window: primaryWindow, currentPrice: $0, now: now) }
        secondaryChange = price.flatMap { baseline.change(window: secondaryWindow, currentPrice: $0, now: now) }
    }

    /// Fetches the historical candle baseline for the selected coin. `force`
    /// refetches immediately; otherwise it is skipped while the cached baseline
    /// is still fresh, so it is safe to call on every tick.
    private func refreshBaseline(force: Bool) {
        let coinID = selectedCoin.id
        if !force,
           baselineCoinID == coinID,
           let lastBaselineFetch,
           Date().timeIntervalSince(lastBaselineFetch) < Self.baselineRefreshInterval {
            return
        }

        baselineTask?.cancel()
        let service = candleService
        baselineTask = Task { [weak self] in
            let candles = try? await service.candles(coinID: coinID)
            guard let self, !Task.isCancelled, let candles else { return }
            guard self.selectedCoin.id == coinID else { return }
            self.baseline = PriceBaseline(candles: candles)
            self.baselineCoinID = coinID
            self.lastBaselineFetch = Date()
            // Aggregate the fine 5m candles into hourly OHLC so the chart shows a
            // readable number of candlesticks (~24) instead of ~288 slivers.
            self.chartCandles = candles.bucketed(bySeconds: 3600)
            self.recomputeChanges()
        }
    }

    private func startStream(symbol: String) {
        let provider = streamProvider
        streamTask?.cancel()
        connectionState = .connecting
        streamFailureCount = 0
        errorMessage = nil
        streamTask = Task { [weak self] in
            guard let self else { return }
            var delay: Duration = .seconds(1)
            while !Task.isCancelled {
                do {
                    for try await tick in provider.streamTicker(symbol: symbol) {
                        guard self.selectedCoin.id == symbol else {
                            return
                        }
                        // Alerts run on every raw tick so no crossing is missed;
                        // UI state is updated on a throttled cadence via applyTick.
                        self.checkAlerts(price: tick.price, symbol: tick.id)
                        self.tickSubject.send(tick)
                        delay = .seconds(1)
                    }
                    self.registerStreamInterruption()
                } catch is CancellationError {
                    return
                } catch {
                    guard self.selectedCoin.id == symbol else {
                        return
                    }
                    self.registerStreamInterruption()
                }
                try? await Task.sleep(for: delay)
                delay = min(delay * 2, .seconds(60))
            }
        }
    }

    private func checkAlerts(price: Decimal, symbol: String) {
        for index in alerts.indices where !alerts[index].isTriggered && alerts[index].symbol == symbol {
            let triggered = switch alerts[index].direction {
            case .above:
                price >= alerts[index].threshold
            case .below:
                price <= alerts[index].threshold
            }

            if triggered {
                alerts[index].isTriggered = true
                fireNotification(for: alerts[index], price: price)
            }
        }
    }

    private func fireNotification(for alert: PriceAlert, price: Decimal) {
        let content = UNMutableNotificationContent()
        content.title = "\(displaySymbol(for: alert.symbol)) Alert"
        content.body = "\(displaySymbol(for: alert.symbol)) is \(alert.direction.label.lowercased()) \(formatPrice(alert.threshold)); now at \(formatPrice(price))"
        content.sound = .default
        let request = UNNotificationRequest(identifier: alert.id.uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func displaySymbol(for symbolID: String) -> String {
        coins.first(where: { $0.id == symbolID })?.symbol ?? symbolID
    }

    func formatPrice(_ price: Decimal) -> String {
        "$\(DisplayFormatters.priceString(price))"
    }

    private func saveAlerts() {
        guard let data = try? JSONEncoder().encode(alerts) else {
            return
        }
        UserDefaults.standard.set(data, forKey: Self.priceAlertsKey)
    }

    private static func loadAlerts() -> [PriceAlert] {
        guard let data = UserDefaults.standard.data(forKey: priceAlertsKey),
              let alerts = try? JSONDecoder().decode([PriceAlert].self, from: data) else {
            return []
        }
        return alerts
    }

    private static func storedCoin(in coins: [CoinInfo]) -> CoinInfo {
        if let selectedCoinID = UserDefaults.standard.string(forKey: selectedCoinIDKey),
           let storedCoin = coins.first(where: { $0.id == selectedCoinID }) {
            return storedCoin
        }
        return coins[0]
    }

    private static func storedWindow(forKey key: String, default fallback: ChangeWindow) -> ChangeWindow {
        guard let rawValue = UserDefaults.standard.string(forKey: key),
              let window = ChangeWindow(rawValue: rawValue) else {
            return fallback
        }
        return window
    }

    private static func notificationStatusText(for status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "Notifications not requested"
        case .denied:
            return "Notifications blocked"
        case .authorized:
            return "Notifications enabled"
        case .provisional:
            return "Notifications provisional"
        case .ephemeral:
            return "Notifications temporary"
        @unknown default:
            return "Notification status unknown"
        }
    }

    private nonisolated static func currentNotificationAuthorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    private static let selectedCoinIDKey = "selectedCoinID"
    private static let priceAlertsKey = "priceAlerts"
    private static let primaryWindowKey = "primaryChangeWindow"
    private static let secondaryWindowKey = "secondaryChangeWindow"
    private static let baselineRefreshInterval: TimeInterval = 5 * 60
    private static let offlineThreshold = 4
    private static let catalogCacheKey = "cachedCatalog"
    private static let canUseUserNotifications = Bundle.main.bundleURL.pathExtension == "app"
}
