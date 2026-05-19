import AppKit
import Combine
import SwiftUI
@preconcurrency import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let viewModel = TickerViewModel()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configurePopover()
        UNUserNotificationCenter.current().delegate = self
        bindStatusTitle()
        bindPopoverSize()
        viewModel.start()
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
        statusItem.length = 152
        button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        button.alignment = .center
        button.title = viewModel.statusTitle
        button.action = #selector(togglePopover)
        button.target = self
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(
            width: CryptoMinbarDesign.panelWidth,
            height: PopoverLayout.height(for: viewModel.popoverLayoutState)
        )
        let hostingView = NSHostingView(rootView: PopoverView(viewModel: viewModel))
        let vc = NSViewController()
        vc.view = hostingView
        popover.contentViewController = vc
    }

    private func bindStatusTitle() {
        Publishers.CombineLatest(viewModel.$ticker, viewModel.$selectedCoin)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, let button = self.statusItem.button else { return }
                let title = self.viewModel.statusTitle
                button.attributedTitle = NSAttributedString(
                    string: title,
                    attributes: [
                        .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
                        .foregroundColor: NSColor.labelColor
                    ]
                )
            }
            .store(in: &cancellables)
    }

    private func bindPopoverSize() {
        viewModel.$popoverLayoutState
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                self.popover.contentSize = NSSize(
                    width: CryptoMinbarDesign.panelWidth,
                    height: PopoverLayout.height(for: state)
                )
            }
            .store(in: &cancellables)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
