import AppKit
import ServiceManagement

final class Panel: NSPanel {
    var onCommand: (String, Bool) -> Bool = { _, _ in false }
    var onEscape: () -> Void = {}

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // menu-bar apps have no menu, so edit shortcuts are routed here by hand
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
            if event.keyCode == 53 && flags.isEmpty {
                onEscape()
                return
            }
            if flags.contains(.command), !flags.contains(.option), !flags.contains(.control),
               let key = event.charactersIgnoringModifiers?.lowercased(),
               onCommand(key, flags.contains(.shift)) {
                return
            }
        }
        super.sendEvent(event)
    }
}

final class RootView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 12, yRadius: 12)
        Theme.bg.setFill()
        shape.fill()
        Theme.border.setStroke()
        shape.lineWidth = 1
        shape.stroke()
    }
}

@MainActor
final class PanelController: NSObject {
    let panel = Panel(contentRect: NSRect(x: 0, y: 0, width: Theme.width, height: 120),
                      styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    let list: ListController
    let root = RootView()
    var anchor: () -> NSRect? = { nil }
    var onVisibility: (Bool) -> Void = { _ in }

    private let scroll = NSScrollView()
    private var listHeight: NSLayoutConstraint!
    private let count = NSTextField(labelWithString: "")
    private let clear = FirstMouseButton()
    private let gear = FirstMouseButton()
    private let settings = NSStackView()
    private let bottom = NSStackView()
    private let floatSwitch = NSSwitch()
    private let loginSwitch = NSSwitch()

    var floating: Bool {
        get { UserDefaults.standard.object(forKey: "floatOnTop") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "floatOnTop")
            panel.level = newValue ? .floating : .normal
        }
    }

    init(store: Store) {
        list = ListController(store: store)
        super.init()
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.level = floating ? .floating : .normal
        panel.contentView = root
        panel.onEscape = { [weak self] in self?.hide() }
        panel.onCommand = { [weak self] key, shift in self?.command(key, shift: shift) ?? false }
        list.onChange = { [weak self] in self?.refresh() }
        build()
        refresh()
    }

    private func build() {
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.verticalScrollElasticity = .allowed
        scroll.documentView = list.view
        scroll.translatesAutoresizingMaskIntoConstraints = false
        let clip = scroll.contentView
        NSLayoutConstraint.activate([
            list.view.topAnchor.constraint(equalTo: clip.topAnchor),
            list.view.leadingAnchor.constraint(equalTo: clip.leadingAnchor),
        ])

        count.font = Theme.small
        count.textColor = Theme.dim

        clear.isBordered = false
        clear.attributedTitle = NSAttributedString(
            string: "Clear done", attributes: [.font: Theme.small, .foregroundColor: Theme.dim])
        clear.target = self
        clear.action = #selector(clearDone)

        gear.isBordered = false
        gear.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")?
            .withSymbolConfiguration(.init(pointSize: 11, weight: .regular))
        gear.contentTintColor = Theme.dim
        gear.target = self
        gear.action = #selector(toggleSettings)

        let footer = NSStackView(views: [count, NSView(), clear, gear])
        footer.spacing = 12
        footer.edgeInsets = NSEdgeInsets(top: 0, left: 16, bottom: 0, right: 14)
        footer.heightAnchor.constraint(equalToConstant: 30).isActive = true

        floatSwitch.controlSize = .mini
        floatSwitch.state = floating ? .on : .off
        floatSwitch.target = self
        floatSwitch.action = #selector(floatChanged)
        loginSwitch.controlSize = .mini
        loginSwitch.target = self
        loginSwitch.action = #selector(loginChanged)

        let shortcuts = NSGridView(views: [
            ("⌥Space", "Open or close"), ("↩", "New task"), ("⌘↩", "Mark done"),
            ("⌘⌫", "Delete task"), ("↑ ↓", "Move between tasks"), ("esc", "Close"),
        ].map { [label($0.0, Theme.faint), label($0.1, Theme.dim)] })
        shortcuts.columnSpacing = 14
        shortcuts.rowSpacing = 5
        shortcuts.column(at: 0).width = 52
        shortcuts.setContentHuggingPriority(.required, for: .horizontal)

        let quit = FirstMouseButton()
        quit.isBordered = false
        quit.attributedTitle = NSAttributedString(
            string: "Quit Tick", attributes: [.font: Theme.small, .foregroundColor: Theme.dim])
        quit.target = NSApp
        quit.action = #selector(NSApplication.terminate(_:))

        let toggles = [settingRow("Keep on top", floatSwitch), settingRow("Open at login", loginSwitch)]
        settings.orientation = .vertical
        settings.alignment = .leading
        settings.spacing = 10
        settings.edgeInsets = NSEdgeInsets(top: 4, left: 16, bottom: 12, right: 14)
        for view in toggles + [shortcuts, quit] { settings.addArrangedSubview(view) }
        settings.setCustomSpacing(16, after: toggles[1])
        settings.setCustomSpacing(14, after: shortcuts)
        settings.widthAnchor.constraint(equalToConstant: Theme.width).isActive = true
        for row in toggles {
            row.widthAnchor.constraint(equalToConstant: Theme.width - 30).isActive = true
        }
        settings.isHidden = true

        let line = NSBox()
        line.boxType = .custom
        line.borderWidth = 0
        line.fillColor = Theme.line
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true

        bottom.orientation = .vertical
        bottom.spacing = 0
        bottom.alignment = .width
        bottom.addArrangedSubview(line)
        bottom.addArrangedSubview(footer)
        bottom.addArrangedSubview(settings)

        for v in [scroll, bottom] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(v)
        }
        listHeight = scroll.heightAnchor.constraint(equalToConstant: 40)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: root.topAnchor, constant: 7),
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            listHeight,
            bottom.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 7),
            bottom.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            bottom.trailingAnchor.constraint(equalTo: root.trailingAnchor),
        ])
    }

    private func label(_ text: String, _ color: NSColor) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = Theme.small
        field.textColor = color
        return field
    }

    private func settingRow(_ title: String, _ toggle: NSSwitch) -> NSView {
        NSStackView(views: [label(title, Theme.text), NSView(), toggle])
    }

    func refresh() {
        let open = list.openCount
        let done = list.doneCount
        count.stringValue = open > 0 ? "\(open) left" : (done > 0 ? "All done" : "")
        clear.isHidden = done == 0
        relayout()
    }

    private func relayout() {
        let content = list.view.fittingSize.height
        listHeight.constant = min(max(content, 30), Theme.maxListHeight)
        let height = 7 + listHeight.constant + 7 + bottom.fittingSize.height
        var frame = panel.frame
        frame.size = NSSize(width: Theme.width, height: height)
        if let bar = anchor() {
            let screen = NSScreen.screens.first { $0.frame.contains(NSPoint(x: bar.midX, y: bar.midY)) } ?? NSScreen.main
            let visible = screen?.visibleFrame ?? .zero
            frame.origin.x = min(max(bar.midX - Theme.width / 2, visible.minX + 8), visible.maxX - Theme.width - 8)
            frame.origin.y = bar.minY - 6 - height
        } else {
            frame.origin.y = panel.frame.maxY - height
        }
        panel.setFrame(frame, display: true)
        root.layoutSubtreeIfNeeded()
        panel.invalidateShadow()
    }

    func show() {
        list.prepareForShow()
        refresh()
        panel.orderFrontRegardless()
        panel.makeKey()
        list.focusLast()
        onVisibility(true)
    }

    func hide() {
        panel.orderOut(nil)
        list.pruneEmpty()
        onVisibility(false)
    }

    func clickToggle() {
        panel.isVisible && panel.occlusionState.contains(.visible) ? hide() : show()
    }

    func hotkeyToggle() {
        panel.isVisible && panel.isKeyWindow ? hide() : show()
    }

    private func command(_ key: String, shift: Bool) -> Bool {
        switch (key, shift) {
        case ("x", false): return NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
        case ("c", false): return NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
        case ("v", false): return NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
        case ("a", false): return NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
        case ("z", false): return NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
        case ("z", true): return NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
        case ("\r", false): list.toggleFocused()
        case ("\u{7f}", false): list.deleteFocused()
        case ("w", false): hide()
        case ("q", false): NSApp.terminate(nil)
        case (",", false): toggleSettings()
        default: return false
        }
        return true
    }

    @objc private func clearDone() { list.clearDone() }

    @objc func toggleSettings() {
        settings.isHidden.toggle()
        if !settings.isHidden { loginSwitch.state = SMAppService.mainApp.status == .enabled ? .on : .off }
        relayout()
    }

    @objc private func floatChanged() { floating = floatSwitch.state == .on }

    @objc private func loginChanged() {
        do {
            if loginSwitch.state == .on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSSound.beep()
        }
        loginSwitch.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }
}
