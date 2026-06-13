import AppKit
import Combine
import Network
import SwiftUI
@preconcurrency import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let viewModel = TickerViewModel()
    private var cancellables = Set<AnyCancellable>()
    private let pathMonitor = NWPathMonitor()
    private var hadNetwork = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configurePopover()
        // UNUserNotificationCenter.current() traps when the process has no app
        // bundle (e.g. launched as a bare binary during development).
        if Bundle.main.bundleURL.pathExtension == "app" {
            UNUserNotificationCenter.current().delegate = self
        }
        bindStatusTitle()
        observeNetworkAndWake()
        viewModel.start()
    }

    /// Reconnect immediately when the network returns or the Mac wakes, instead
    /// of waiting out the websocket's reconnect backoff.
    private func observeNetworkAndWake() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let satisfied = path.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                if satisfied && !self.hadNetwork {
                    await self.viewModel.refreshNow()
                }
                self.hadNetwork = satisfied
            }
        }
        pathMonitor.start(queue: DispatchQueue(label: "network-path-monitor"))

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc private func systemDidWake() {
        Task { @MainActor in await viewModel.refreshNow() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.stop()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        // Fixed width sized for a worst-case title (monospaced digits): wide
        // enough never to clip, constant so the item — and the popover anchored
        // to it — never shift when the price loads or changes width.
        button.font = Self.statusFont
        button.alignment = .left
        button.title = viewModel.statusTitle
        button.action = #selector(togglePopover)
        button.target = self
        updateStatusItemWidth()
    }

    private func updateStatusItemWidth() {
        // Reserve space for the longest realistic string for the current config.
        let template = viewModel.showChangeInBar ? "MMMMMM $199,999.99 +99.99%" : "MMMMMM $199,999.99"
        let width = (template as NSString).size(withAttributes: [.font: Self.statusFont]).width
        statusItem.length = ceil(width) + 6
    }

    private static let statusFont = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

    private func configurePopover() {
        popover.behavior = .transient
        // Let SwiftUI drive the popover height: NSHostingController keeps its
        // preferredContentSize in sync with the view's fitting size, and the
        // popover animates to match. No manual height table required.
        let hostingController = NSHostingController(rootView: PopoverView(viewModel: viewModel))
        hostingController.sizingOptions = .preferredContentSize
        popover.contentViewController = hostingController
    }

    private func bindStatusTitle() {
        // Coalesce menu-bar updates: throttle to ~2Hz and skip redraws when the
        // rendered string is unchanged, so a busy trade stream doesn't rebuild
        // the attributed title (and relayout the status item) on every tick.
        viewModel.$ticker
            .combineLatest(viewModel.$selectedCoin, viewModel.$primaryChange, viewModel.$showChangeInBar)
            .throttle(for: .milliseconds(500), scheduler: RunLoop.main, latest: true)
            .compactMap { [weak self] _ in self?.viewModel.statusTitle }
            .removeDuplicates()
            .sink { [weak self] title in
                self?.applyStatusTitle(title)
            }
            .store(in: &cancellables)

        // Re-reserve width when the 5-min-change toggle changes the title format.
        viewModel.$showChangeInBar
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusItemWidth()
            }
            .store(in: &cancellables)
    }

    private func applyStatusTitle(_ title: String) {
        guard let button = statusItem.button else { return }
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: Self.statusFont,
                .foregroundColor: NSColor.labelColor
            ]
        )
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
