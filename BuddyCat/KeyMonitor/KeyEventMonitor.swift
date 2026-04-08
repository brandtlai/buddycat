import Cocoa
import CoreGraphics

class KeyEventMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var nsEventMonitor: Any?
    private var localMonitor: Any?
    private var pollTimer: Timer?
    var onKeyDown: (() -> Void)?

    init(onKeyDown: @escaping () -> Void) {
        self.onKeyDown = onKeyDown
    }

    func start() {
        let hasPerm = AccessibilityHelper.hasPermission
        NSLog("BuddyCat: start(), hasPermission=\(hasPerm)")
        guard hasPerm else {
            AccessibilityHelper.requestPermission()
            startPermissionPolling()
            return
        }
        setupMonitors()
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        if let m = nsEventMonitor {
            NSEvent.removeMonitor(m)
            nsEventMonitor = nil
        }
        if let m = localMonitor {
            NSEvent.removeMonitor(m)
            localMonitor = nil
        }
    }

    private func startPermissionPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            if AccessibilityHelper.hasPermission {
                self?.pollTimer?.invalidate()
                self?.pollTimer = nil
                self?.setupMonitors()
            }
        }
    }

    private func setupMonitors() {
        // Strategy: try NSEvent global monitor (simpler, fewer issues)
        // plus CGEvent tap as backup
        setupNSEventGlobalMonitor()
        setupCGEventTap()

        // Also add a local monitor to verify event system works at all
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            NSLog("BuddyCat: LOCAL keyDown detected (key: \(event.keyCode))")
            self?.onKeyDown?()
            return event
        }
        NSLog("BuddyCat: All monitors configured")
    }

    private func setupNSEventGlobalMonitor() {
        nsEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            NSLog("BuddyCat: GLOBAL NSEvent keyDown (key: \(event.keyCode))")
            self?.onKeyDown?()
        }
        NSLog("BuddyCat: NSEvent global monitor: \(nsEventMonitor != nil ? "OK" : "FAILED")")
    }

    private func setupCGEventTap() {
        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        // Use a simple C-compatible callback wrapper
        let callback: CGEventTapCallBack = { _, type, event, _ in
            if type == .keyDown {
                NSLog("BuddyCat: CGEvent tap keyDown!")
            }
            if type == .tapDisabledByUserInput || type == .tapDisabledByTimeout {
                NSLog("BuddyCat: CGEvent tap was disabled, this is expected without Input Monitoring")
            }
            // For listenOnly taps, return nil (don't modify events)
            return nil
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: nil
        ) else {
            NSLog("BuddyCat: CGEvent tap creation failed (expected without Input Monitoring permission)")
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        NSLog("BuddyCat: CGEvent tap created and enabled")
    }
}
