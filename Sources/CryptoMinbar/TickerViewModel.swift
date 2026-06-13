import AppKit
import Foundation
import ServiceManagement
import UserNotifications

@MainActor
final class TickerViewModel: ObservableObject {
    @Published private(set) var ticker: BTCTicker?
    @Published private(set) var coins: [CoinInfo] = CoinInfo.supportedSymbols
    @Published private(set) var selectedCoin: CoinInfo = CoinInfo.supportedSymbols[0] {
        didSet { updatePopoverLayoutState() }
    }
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var errorMessage: String? {
        didSet { updatePopoverLayoutState() }
    }
    @Published private(set) var isRefreshing = false
    @Published var isShowingAPISettings = false {
        didSet { updatePopoverLayoutState() }
    }
    @Published private(set) var notificationStatusText = "Checking notifications..."
    @Published private(set) var popoverLayoutState = PopoverLayoutState(
        isShowingAPISettings: false,
        selectedCoinAlertCount: 0,
        hasErrorMessage: false
    )
    @Published var alerts: [PriceAlert] {
        didSet {
            saveAlerts()
            updatePopoverLayoutState()
        }
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
    private var streamTask: Task<Void, Never>?
    private var connectionSetupTask: Task<Void, Never>?
    private var connectionRequestVersion = 0
    private var isUpdatingLaunchAtLogin = false

    init(streamProvider: any TickerStreamProvider = HyperliquidWebSocketProvider()) {
        self.streamProvider = streamProvider
        self.showChangeInBar = UserDefaults.standard.bool(forKey: "showChangeInBar")
        self.alerts = Self.loadAlerts()
        self.coins = CoinInfo.supportedSymbols
        self.selectedCoin = Self.storedCoin(in: CoinInfo.supportedSymbols)
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
        updatePopoverLayoutState()
    }

    deinit {
        streamTask?.cancel()
    }

    var statusTitle: String {
        guard let ticker else { return "\(selectedCoin.symbol) --" }
        let price = Self.priceFormatter.string(for: ticker.price) ?? "--"
        guard showChangeInBar, let change = ticker.percentChange5m else {
            return "\(ticker.symbol) \(price)"
        }
        let formatted = DisplayFormatters.percent.string(from: NSDecimalNumber(decimal: change)) ?? "--"
        let sign = change >= 0 ? "+" : ""
        return "\(ticker.symbol) \(price) \(sign)\(formatted)%"
    }

    var feedSourceLabel: String { "Hyperliquid" }

    func start() {
        if Self.canUseUserNotifications {
            Task { [weak self] in
                await self?.refreshNotificationStatus()
            }
        } else {
            notificationStatusText = "Notifications unavailable"
        }
        requestConnect()
    }

    func stop() {
        connectionRequestVersion += 1
        connectionSetupTask?.cancel()
        connectionSetupTask = nil
        streamTask?.cancel()
        streamTask = nil
        isRefreshing = false
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
        UserDefaults.standard.set(coin.id, forKey: Self.selectedCoinIDKey)
        requestConnect()
    }

    func refreshNow() async {
        requestConnect()
    }

    func copyPriceToClipboard() {
        guard ticker != nil else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(statusTitle, forType: .string)
    }

    func toggleAPISettings() {
        isShowingAPISettings.toggle()
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
        content.title = "Crypto Minibar"
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
        isRefreshing = false
    }

    private func startStream(symbol: String) {
        let provider = streamProvider
        streamTask?.cancel()
        isRefreshing = true
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
                        self.ticker = tick
                        self.lastUpdated = Date()
                        self.isRefreshing = false
                        self.errorMessage = nil
                        self.checkAlerts(price: tick.price, symbol: tick.id)
                        delay = .seconds(1)
                    }
                    self.isRefreshing = true
                    self.errorMessage = "Reconnecting..."
                } catch is CancellationError {
                    return
                } catch {
                    guard self.selectedCoin.id == symbol else {
                        return
                    }
                    self.isRefreshing = true
                    self.errorMessage = "Reconnecting... (\(error.localizedDescription))"
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

    private func updatePopoverLayoutState() {
        popoverLayoutState = PopoverLayoutState(
            isShowingAPISettings: isShowingAPISettings,
            selectedCoinAlertCount: alerts.filter { $0.symbol == selectedCoin.id }.count,
            hasErrorMessage: errorMessage != nil
        )
    }

    func displaySymbol(for symbolID: String) -> String {
        CoinInfo.supportedSymbols.first(where: { $0.id == symbolID })?.symbol ?? symbolID
    }

    func formatPrice(_ price: Decimal) -> String {
        DisplayFormatters.price.string(from: NSDecimalNumber(decimal: price)) ?? "\(price)"
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
    private static let canUseUserNotifications = Bundle.main.bundleURL.pathExtension == "app"

    private static let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.locale = Locale(identifier: "en_US")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}
