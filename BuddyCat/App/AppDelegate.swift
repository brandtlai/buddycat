import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItemController: StatusItemController!
    var keystrokeTracker: KeystrokeTracker!
    var keyEventMonitor: KeyEventMonitor!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("BuddyCat: applicationDidFinishLaunching")
        keystrokeTracker = KeystrokeTracker()
        statusItemController = StatusItemController(tracker: keystrokeTracker)
        keyEventMonitor = KeyEventMonitor { [weak self] in
            NSLog("BuddyCat: onKeyDown callback invoked!")
            self?.keystrokeTracker.recordKeystroke()
            self?.statusItemController.animatePaw()
        }
        keyEventMonitor.start()
        NSLog("BuddyCat: Setup complete")
    }
}
