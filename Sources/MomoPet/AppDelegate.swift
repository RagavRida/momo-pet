import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var overlay: OverlayController?
    var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        overlay = OverlayController()
        overlay?.start()

        menuBar = MenuBarController(overlay: overlay!)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
