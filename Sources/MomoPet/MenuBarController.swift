import AppKit

final class MenuBarController {
    private let item: NSStatusItem
    private let overlay: OverlayController
    private var paused = false
    private var mimicOn = false
    private var mimicMenuItem: NSMenuItem!
    private var pauseMenuItem: NSMenuItem!

    init(overlay: OverlayController) {
        self.overlay = overlay
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = item.button {
            button.title = "◐"
            button.toolTip = "Momo"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Momo", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())

        pauseMenuItem = NSMenuItem(title: "Pause", action: #selector(togglePause), keyEquivalent: "p")
        menu.addItem(pauseMenuItem)

        menu.addItem(NSMenuItem(title: "Sleep now", action: #selector(sleepNow), keyEquivalent: "s"))

        mimicMenuItem = NSMenuItem(title: "Mimic mode: off", action: #selector(toggleMimic), keyEquivalent: "m")
        menu.addItem(mimicMenuItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        for mi in menu.items where mi.action != nil {
            mi.target = self
        }
        item.menu = menu
    }

    @objc private func togglePause() {
        paused.toggle()
        overlay.behavior?.setPaused(paused)
        pauseMenuItem.title = paused ? "Resume" : "Pause"
    }

    @objc private func sleepNow() {
        overlay.behavior?.forceSleep()
    }

    @objc private func toggleMimic() {
        if mimicOn {
            overlay.mimic.disable()
            mimicOn = false
            mimicMenuItem.title = "Mimic mode: off"
        } else {
            mimicMenuItem.title = "Mimic mode: requesting…"
            overlay.mimic.enable { [weak self] granted in
                guard let self = self else { return }
                self.mimicOn = granted
                self.mimicMenuItem.title = granted ? "Mimic mode: on 🎤" : "Mimic mode: denied"
                if granted {
                    self.overlay.pet?.setMood(.curious)
                } else {
                    let alert = NSAlert()
                    alert.messageText = "Microphone access denied"
                    alert.informativeText = "Enable microphone for Momo in System Settings → Privacy & Security → Microphone."
                    alert.runModal()
                }
            }
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
