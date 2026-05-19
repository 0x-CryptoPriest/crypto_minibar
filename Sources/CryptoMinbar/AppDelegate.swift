import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let viewModel = TickerViewModel()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configurePopover()
        bindStatusTitle()
        viewModel.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.stop()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else {
            return
        }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }
        button.title = viewModel.statusTitle
        button.action = #selector(togglePopover)
        button.target = self
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 300, height: 230)
        popover.contentViewController = NSHostingController(rootView: PopoverView(viewModel: viewModel))
    }

    private func bindStatusTitle() {
        Publishers.CombineLatest(viewModel.$ticker, viewModel.$selectedCoin)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.statusItem.button?.title = self?.viewModel.statusTitle ?? "BTC --"
            }
            .store(in: &cancellables)
    }
}
