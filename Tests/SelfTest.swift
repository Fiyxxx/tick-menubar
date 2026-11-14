import AppKit

// drives the real panel through typing and shortcuts, then saves snapshots
@MainActor
final class SelfTest: NSObject, NSApplicationDelegate {
    let out: String
    var failures = 0

    init(out: String) { self.out = out }

    func expect(_ ok: Bool, _ name: String) {
        print(ok ? "pass  \(name)" : "FAIL  \(name)")
        if !ok { failures += 1 }
    }

    func snapshot(_ view: NSView, _ name: String) {
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        view.layoutSubtreeIfNeeded()
        let size = view.bounds.size
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let context = NSGraphicsContext(bitmapImageRep: rep)!
        context.cgContext.scaleBy(x: 2, y: 2)
        view.displayIgnoringOpacity(view.bounds, in: context)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(out)/\(name).png"))
    }

    func editor(_ c: PanelController) -> NSTextView { c.panel.firstResponder as! NSTextView }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let file = URL(fileURLWithPath: "\(out)/todos.json")
        let seed = [
            Todo(text: "Buy oat milk"),
            Todo(text: "Renew passport and book the photo appointment before the end of the month"),
            Todo(text: "Book flights", done: true),
        ]
        try! JSONEncoder().encode(seed).write(to: file)

        UserDefaults.standard.removeObject(forKey: "topLeft")
        let store = Store(url: file)
        let c = PanelController(store: store)
        c.panel.setFrameTopLeftPoint(NSPoint(x: 900, y: 800))
        c.show()

        expect(c.list.items.count == 4, "opening adds an empty line at the bottom")
        expect(c.list.focusedIndex == 3, "the empty line is focused")
        expect(c.panel.isKeyWindow, "panel takes keyboard focus")

        editor(c).insertText("Call mom", replacementRange: editor(c).selectedRange())
        expect(c.list.items[3].text == "Call mom", "typing updates the item")

        editor(c).doCommand(by: #selector(NSResponder.insertNewline(_:)))
        expect(c.list.items.count == 5 && c.list.focusedIndex == 4, "enter makes a new bullet below")

        editor(c).doCommand(by: #selector(NSResponder.insertNewline(_:)))
        expect(c.list.items.count == 5, "enter on an empty line does nothing")

        editor(c).doCommand(by: #selector(NSResponder.deleteBackward(_:)))
        expect(c.list.items.count == 4 && c.list.focusedIndex == 3, "backspace on empty removes it and goes up")

        c.list.toggleFocused()
        expect(c.list.items[3].done, "cmd-enter marks done")

        editor(c).doCommand(by: #selector(NSResponder.moveUp(_:)))
        expect(c.list.focusedIndex == 2, "up arrow moves to previous task")

        snapshot(c.root, "panel")

        c.toggleSettings()
        snapshot(c.root, "settings")
        c.toggleSettings()

        c.list.clearDone()
        expect(c.list.items.map(\.text) == ["Buy oat milk", "Renew passport and book the photo appointment before the end of the month"],
               "clear done removes only finished tasks")

        c.list.focus(0)
        c.list.deleteFocused()
        expect(c.list.items.count == 1, "cmd-backspace deletes the focused task")

        c.show()
        editor(c).insertText("Dentist 3pm", replacementRange: editor(c).selectedRange())
        c.hide()
        expect(!c.panel.isVisible, "hide closes the panel")
        store.flush()
        let saved = store.load()
        expect(saved.map(\.text) == ["Renew passport and book the photo appointment before the end of the month", "Dentist 3pm"],
               "saved file matches and has no blank lines")

        let reloaded = ListController(store: Store(url: file))
        expect(reloaded.items.count == 2, "tasks survive a relaunch")

        // real key events through the window, same path as the keyboard
        func key(_ chars: String, _ code: UInt16, _ flags: NSEvent.ModifierFlags = []) {
            let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                                         windowNumber: c.panel.windowNumber, context: nil, characters: chars,
                                         charactersIgnoringModifiers: chars, isARepeat: false, keyCode: code)!
            c.panel.sendEvent(event)
        }
        c.hotkeyToggle()
        expect(c.panel.isVisible && c.panel.isKeyWindow, "hotkey opens and focuses")
        let before = c.list.items.count
        for ch in "Gym" { key(String(ch), 0) }
        expect(c.list.items.last?.text == "Gym", "typed keys land in the new line")
        key("\r", 36)
        expect(c.list.items.count == before + 1, "return key adds a bullet")
        for ch in "Rent" { key(String(ch), 0) }
        key("\r", 36, .command)
        expect(c.list.items.last?.done == true, "cmd-return key marks done")
        key("\u{7f}", 51, .command)
        expect(!c.list.items.contains { $0.text == "Rent" }, "cmd-backspace key deletes")
        key("\u{1b}", 53)
        expect(!c.panel.isVisible, "esc closes")
        c.hotkeyToggle()
        c.hotkeyToggle()
        expect(!c.panel.isVisible, "hotkey toggles closed again")

        c.show()
        c.panel.setFrameTopLeftPoint(NSPoint(x: 300, y: 600))
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        for ch in "Moved" { key(String(ch), 0) }
        key("\r", 36)
        expect(c.panel.frame.minX == 300 && c.panel.frame.maxY == 600, "dragged panel stays put while it grows")
        c.hide()
        c.show()
        expect(c.panel.frame.minX == 300 && c.panel.frame.maxY == 600, "dragged position is remembered on reopen")
        c.resetPosition()
        expect(c.savedTopLeft == nil, "reset forgets the dragged position")
        c.hide()
        UserDefaults.standard.removeObject(forKey: "topLeft")

        print(failures == 0 ? "all passed" : "\(failures) failed")
        exit(failures == 0 ? 0 : 1)
    }
}
