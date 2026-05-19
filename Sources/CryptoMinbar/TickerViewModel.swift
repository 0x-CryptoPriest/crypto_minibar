import AppKit
import Foundation
import ServiceManagement
import UserNotifications

@MainActor
final class TickerViewModel: ObservableObject {
    @Published private(set) var ticker: BTCTicker?
    @Published private(set) var coins: [CoinInfo] = CoinInfo.allTickSymbols
    @Published private(set) var selectedCoin: CoinInfo = .bitcoin {
        didSet { updatePopoverLayoutState() }
    }
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var errorMessage: String? {
        didSet { updatePopoverLayoutState() }
    }
    @Published private(set) var isRefreshing = false
    @Published var apiKeyInput = ""
    @Published var isShowingAPISettings = false {
        didSet { updatePopoverLayoutState() }
    }
    @Published private(set) var hasSavedAPIKey = false
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

    private let streamProvider: TickerStreamProvider
    private let tokenStore: AllTickTokenStore
    private var streamTask: Task<Void, Never>?
    private var isUpdatingLaunchAtLogin = false

    init(
        streamProvider: TickerStreamProvider = AllTickWebSocketProvider(),
        tokenStore: AllTickTokenStore = AllTickTokenStore()
    ) {
        self.streamProvider = streamProvider
        self.tokenStore = tokenStore
        self.showChangeInBar = UserDefaults.standard.bool(forKey: "showChangeInBar")
        self.alerts = Self.loadAlerts()
        if let selectedCoinID = UserDefaults.standard.string(forKey: Self.selectedCoinIDKey),
           let storedCoin = CoinInfo.allTickSymbols.first(where: { $0.id == selectedCoinID }) {
            self.selectedCoin = storedCoin
        }
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
        updatePopoverLayoutState()
    }

    deinit {
        streamTask?.cancel()
    }

    var statusTitle: String {
        guard let ticker else { return "\(selectedCoin.symbol) --" }
        let price = Self.priceFormatter.string(for: ticker.priceUSD) ?? "--"
        guard showChangeInBar, let change = ticker.percentChange5m else {
            return "\(ticker.symbol) \(price)"
        }
        let formatted = DisplayFormatters.percent.string(from: NSDecimalNumber(decimal: change)) ?? "--"
        let sign = change >= 0 ? "+" : ""
        return "\(ticker.symbol) \(price) \(sign)\(formatted)%"
    }

    func start() {
        hasSavedAPIKey = tokenStore.readToken() != nil
        refreshNotificationStatus()
        connectWithSavedToken()
    }

    func stop() {
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
        guard let token = tokenStore.readToken() else {
            return
        }
        connect(token: token, symbol: coin.id)
    }

    func refreshNow() async {
        connectWithSavedToken()
    }

    func copyPriceToClipboard() {
        guard ticker != nil else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(statusTitle, forType: .string)
    }

    func saveAPIKey() {
        let token = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            errorMessage = "Enter an AllTick API key first."
            return
        }
        do {
            try tokenStore.saveToken(token)
            apiKeyInput = ""
            hasSavedAPIKey = true
            isShowingAPISettings = false
            errorMessage = nil
            connect(token: token, symbol: selectedCoin.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearAPIKey() {
        do {
            try tokenStore.deleteToken()
            stop()
            ticker = nil
            lastUpdated = nil
            hasSavedAPIKey = false
            errorMessage = "API key removed. Enter a new key to reconnect."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleAPISettings() {
        isShowingAPISettings.toggle()
    }

    func requestNotificationPermission() {
        notificationStatusText = "Checking notifications..."
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    Task { @MainActor in
                        self?.refreshNotificationStatus()
                        if granted {
                            self?.sendTestNotification()
                        }
                    }
                }
            case .denied:
                Task { @MainActor in
                    self?.notificationStatusText = "Notifications blocked"
                    self?.openNotificationSettings()
                }
            case .authorized, .provisional, .ephemeral:
                Task { @MainActor in
                    self?.refreshNotificationStatus()
                    self?.sendTestNotification()
                }
            @unknown default:
                Task { @MainActor in
                    self?.refreshNotificationStatus()
                }
            }
        }
    }

    func sendTestNotification() {
        notificationStatusText = "Sending test notification..."
        let content = UNMutableNotificationContent()
        content.title = "Crypto Minibar"
        content.body = "Notifications are ready."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "notification-test-\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            Task { @MainActor in
                if let error {
                    self?.notificationStatusText = "Notification failed"
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.notificationStatusText = "Test notification sent"
                }
            }
        }
    }

    func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let authorizationStatus = settings.authorizationStatus
            Task { @MainActor in
                self?.notificationStatusText = Self.notificationStatusText(for: authorizationStatus)
            }
        }
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

    private func connectWithSavedToken() {
        guard let token = tokenStore.readToken() else {
            hasSavedAPIKey = false
            errorMessage = "Enter your AllTick API key to start \(selectedCoin.id) live quotes."
            return
        }
        hasSavedAPIKey = true
        connect(token: token, symbol: selectedCoin.id)
    }

    private func connect(token: String, symbol: String) {
        streamTask?.cancel()
        isRefreshing = true
        errorMessage = nil
        streamTask = Task { [weak self] in
            guard let self else { return }
            var delay: Duration = .seconds(1)
            while !Task.isCancelled {
                do {
                    for try await tick in streamProvider.streamTicker(token: token, symbol: symbol) {
                        guard self.selectedCoin.id == symbol else {
                            return
                        }
                        self.ticker = tick
                        self.lastUpdated = Date()
                        self.isRefreshing = false
                        self.errorMessage = nil
                        self.checkAlerts(price: tick.priceUSD, symbol: tick.id)
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
        CoinInfo.allTickSymbols.first(where: { $0.id == symbolID })?.symbol ?? symbolID
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

    private static let selectedCoinIDKey = "selectedCoinID"
    private static let priceAlertsKey = "priceAlerts"

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
