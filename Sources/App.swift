import AppKit
import Carbon
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = Store()
    var item: NSStatusItem!
    var panel: PanelController!
    var hotkey: Hotkey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = PanelController(store: store)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "Tick")
            image?.isTemplate = true
            button.image = image
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        panel.anchor = { [weak self] in self?.item.button?.window?.frame }
        panel.onVisibility = { [weak self] open in
            DispatchQueue.main.async { self?.item.button?.highlight(open) }
        }
        hotkey = Hotkey(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey)) { [weak self] in
            self?.panel.hotkeyToggle()
        }
        registerLoginOnce()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.flush()
    }

    @objc private func clicked() {
        guard NSApp.currentEvent?.type == .rightMouseUp else { return panel.clickToggle() }
        let menu = NSMenu()
        menu.addItem(withTitle: "Settings", action: #selector(openSettings), keyEquivalent: "").target = self
        if panel.savedTopLeft != nil {
            menu.addItem(withTitle: "Move Back Under Icon", action: #selector(resetPosition), keyEquivalent: "").target = self
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Tick", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    @objc private func resetPosition() { panel.resetPosition() }

    @objc private func openSettings() {
        if !panel.panel.isVisible { panel.show() }
        panel.toggleSettings()
    }

    // start at login by default, but only decide that once so the toggle sticks
    private func registerLoginOnce() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "loginConfigured") else { return }
        defaults.set(true, forKey: "loginConfigured")
        try? SMAppService.mainApp.register()
    }
}
