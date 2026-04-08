import AppKit
import SwiftUI

class StatusItemController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let tracker: KeystrokeTracker
    private var idleTimer: Timer?
    private var lastPaw: CatFrame = .leftPaw
    private var globalClickMonitor: Any?

    init(tracker: KeystrokeTracker) {
        self.tracker = tracker
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            button.image = CatIconRenderer.image(for: .idle)
            button.imagePosition = .imageOnly
            button.action = #selector(handleClick)
            button.target = self
        }

        let hostingController = NSHostingController(rootView: StatsPopoverView(tracker: tracker))
        popover.contentViewController = hostingController
        popover.behavior = .transient
        popover.delegate = self
    }

    func animatePaw() {
        lastPaw = (lastPaw == .leftPaw) ? .rightPaw : .leftPaw
        statusItem.button?.image = CatIconRenderer.image(for: lastPaw)

        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.statusItem.button?.image = CatIconRenderer.image(for: .idle)
        }
    }

    @objc private func handleClick() {
        if popover.isShown {
            closePopover()
        } else if let button = statusItem.button {
            tracker.refreshStats()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            addGlobalClickMonitor()
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        removeGlobalClickMonitor()
    }

    private func addGlobalClickMonitor() {
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func removeGlobalClickMonitor() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }

    func popoverDidClose(_ notification: Notification) {
        removeGlobalClickMonitor()
    }
}
