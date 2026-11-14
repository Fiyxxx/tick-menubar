import AppKit

@MainActor
final class ListController: NSObject {
    let view = FlippedView()
    let stack = NSStackView()
    private(set) var items: [Todo]
    private var rows: [RowView] = []
    private let store: Store
    var onChange: () -> Void = {}

    init(store: Store) {
        self.store = store
        items = store.load()
        super.init()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: Theme.width),
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        for (i, todo) in items.enumerated() { insertRow(todo, at: i) }
    }

    var openCount: Int { items.filter { !$0.done && !$0.text.isBlank }.count }
    var doneCount: Int { items.filter(\.done).count }
    var focusedIndex: Int? { rows.firstIndex { $0.field.currentEditor() != nil } }

    private func insertRow(_ todo: Todo, at i: Int) {
        let row = RowView(todo: todo, list: self)
        stack.insertArrangedSubview(row, at: i)
        row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        rows.insert(row, at: i)
    }

    private func changed() {
        store.save(items)
        onChange()
    }

    private func add(at i: Int) {
        let todo = Todo()
        items.insert(todo, at: i)
        insertRow(todo, at: i)
        changed()
    }

    private func remove(at i: Int) {
        items.remove(at: i)
        rows.remove(at: i).removeFromSuperview()
        changed()
    }

    func focus(_ i: Int, atEnd: Bool = true) {
        guard rows.indices.contains(i) else { return }
        let row = rows[i]
        view.window?.makeFirstResponder(row.field)
        if let editor = row.field.currentEditor() {
            editor.selectedRange = NSRange(location: atEnd ? editor.string.utf16.count : 0, length: 0)
        }
        DispatchQueue.main.async { row.scrollToVisible(row.bounds.insetBy(dx: 0, dy: -6)) }
    }

    // always open on an empty line at the bottom, ready to type
    func prepareForShow() {
        if items.last.map({ !$0.text.isBlank }) ?? true { add(at: items.count) }
    }

    func focusLast() { focus(rows.count - 1) }

    func pruneEmpty() {
        for i in items.indices.reversed() where items[i].text.isBlank { remove(at: i) }
    }

    func clearDone() {
        for i in items.indices.reversed() where items[i].done { remove(at: i) }
        if rows.isEmpty { add(at: 0) }
        focusLast()
    }

    func toggleFocused() {
        if let i = focusedIndex { toggle(rows[i]) }
    }

    func deleteFocused() {
        guard let i = focusedIndex else { return }
        remove(at: i)
        if rows.isEmpty { add(at: 0) }
        focus(min(i, rows.count - 1))
    }

    // row callbacks

    func textChanged(_ row: RowView) {
        guard let i = rows.firstIndex(of: row) else { return }
        items[i].text = row.field.currentEditor()?.string ?? row.field.stringValue
        changed()
    }

    func toggle(_ row: RowView) {
        guard let i = rows.firstIndex(of: row), !items[i].text.isBlank else { return }
        items[i].done.toggle()
        row.done = items[i].done
        changed()
    }

    func delete(_ row: RowView) {
        guard let i = rows.firstIndex(of: row) else { return }
        let wasEditing = row.field.currentEditor() != nil
        remove(at: i)
        if rows.isEmpty { add(at: 0) }
        if wasEditing { focus(min(i, rows.count - 1)) }
    }

    func enter(_ row: RowView) {
        guard let i = rows.firstIndex(of: row), !items[i].text.isBlank else { return }
        if rows.indices.contains(i + 1), items[i + 1].text.isBlank {
            focus(i + 1)
        } else {
            add(at: i + 1)
            focus(i + 1)
        }
    }

    func backspaceOnEmpty(_ row: RowView) {
        guard let i = rows.firstIndex(of: row), rows.count > 1 else { return }
        remove(at: i)
        if i > 0 { focus(i - 1) } else { focus(0, atEnd: false) }
    }

    func move(from row: RowView, by step: Int) {
        guard let i = rows.firstIndex(of: row) else { return }
        focus(i + step, atEnd: step > 0 ? false : true)
    }
}

@MainActor
final class RowView: NSView, NSTextFieldDelegate {
    let field = GrowingField()
    let check = CheckBox()
    let remove = FirstMouseButton()
    weak var list: ListController?
    var done: Bool { didSet { check.done = done; restyle() } }

    init(todo: Todo, list: ListController) {
        done = todo.done
        self.list = list
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        field.stringValue = todo.text
        field.delegate = self
        field.onFocus = { [weak self] in self?.restyle() }
        field.placeholderAttributedString = NSAttributedString(
            string: "New task", attributes: [.foregroundColor: Theme.faint, .font: Theme.font])

        check.done = todo.done
        check.onToggle = { [weak self] in
            guard let self else { return }
            self.list?.toggle(self)
        }

        remove.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Delete")?
            .withSymbolConfiguration(.init(pointSize: 9, weight: .semibold))
        remove.isBordered = false
        remove.contentTintColor = Theme.dim
        remove.target = self
        remove.action = #selector(removeClicked)
        remove.alphaValue = 0

        for v in [check, field, remove] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        NSLayoutConstraint.activate([
            check.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            check.widthAnchor.constraint(equalToConstant: 16),
            check.heightAnchor.constraint(equalToConstant: 16),
            check.topAnchor.constraint(equalTo: field.topAnchor, constant: 0.5),
            field.leadingAnchor.constraint(equalTo: check.trailingAnchor, constant: 10),
            field.widthAnchor.constraint(equalToConstant: Theme.fieldWidth),
            field.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            field.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            remove.leadingAnchor.constraint(equalTo: field.trailingAnchor, constant: 6),
            remove.centerYAnchor.constraint(equalTo: check.centerYAnchor),
            remove.widthAnchor.constraint(equalToConstant: 14),
            remove.heightAnchor.constraint(equalToConstant: 14),
        ])
        restyle()
    }

    required init?(coder: NSCoder) { fatalError() }

    private var attributes: [NSAttributedString.Key: Any] {
        [
            .font: Theme.font,
            .foregroundColor: done ? Theme.dim : Theme.text,
            .strikethroughStyle: done ? NSUnderlineStyle.single.rawValue : 0,
        ]
    }

    func restyle() {
        field.textColor = done ? Theme.dim : Theme.text
        if let editor = field.currentEditor() as? NSTextView {
            editor.textStorage?.setAttributes(attributes, range: NSRange(location: 0, length: editor.string.utf16.count))
            editor.typingAttributes = attributes
        } else {
            field.attributedStringValue = NSAttributedString(string: field.stringValue, attributes: attributes)
        }
    }

    @objc private func removeClicked() { list?.delete(self) }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) { remove.animator().alphaValue = 1 }
    override func mouseExited(with event: NSEvent) { remove.animator().alphaValue = 0 }

    // the field editor drops the strikethrough, so restyle once it settles
    func controlTextDidEndEditing(_ obj: Notification) {
        DispatchQueue.main.async { self.restyle() }
    }

    func controlTextDidChange(_ obj: Notification) {
        field.invalidateIntrinsicContentSize()
        list?.textChanged(self)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard let list else { return false }
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            list.enter(self)
        case #selector(NSResponder.deleteBackward(_:)):
            guard textView.string.isEmpty else { return false }
            list.backspaceOnEmpty(self)
        case #selector(NSResponder.moveUp(_:)):
            guard textView.caretOnLine(first: true) else { return false }
            list.move(from: self, by: -1)
        case #selector(NSResponder.moveDown(_:)):
            guard textView.caretOnLine(first: false) else { return false }
            list.move(from: self, by: 1)
        case #selector(NSResponder.insertTab(_:)):
            list.move(from: self, by: 1)
        case #selector(NSResponder.insertBacktab(_:)):
            list.move(from: self, by: -1)
        default:
            return false
        }
        return true
    }
}

final class GrowingField: NSTextField {
    var onFocus: () -> Void = {}

    override func becomeFirstResponder() -> Bool {
        let focused = super.becomeFirstResponder()
        if focused { DispatchQueue.main.async { self.onFocus() } }
        return focused
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        isBordered = false
        isBezeled = false
        drawsBackground = false
        focusRingType = .none
        font = Theme.font
        textColor = Theme.text
        usesSingleLineMode = false
        lineBreakMode = .byWordWrapping
        maximumNumberOfLines = 0
        cell?.wraps = true
        cell?.isScrollable = false
    }

    required init?(coder: NSCoder) { fatalError() }

    // height follows the wrapped text, including while it's being edited
    override var intrinsicContentSize: NSSize {
        let text = currentEditor()?.string ?? stringValue
        let bounds = (text.isEmpty ? " " : text as NSString).boundingRect(
            with: NSSize(width: Theme.fieldWidth - 4, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: Theme.font])
        return NSSize(width: NSView.noIntrinsicMetric, height: ceil(bounds.height))
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class CheckBox: NSView {
    var done = false { didSet { needsDisplay = true } }
    var onToggle: () -> Void = {}

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { onToggle() }

    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 1, dy: 1)
        let circle = NSBezierPath(ovalIn: r)
        guard done else {
            circle.lineWidth = 1.2
            Theme.dim.setStroke()
            circle.stroke()
            return
        }
        Theme.check.setFill()
        circle.fill()
        let tick = NSBezierPath()
        tick.move(to: NSPoint(x: r.minX + r.width * 0.28, y: r.minY + r.height * 0.50))
        tick.line(to: NSPoint(x: r.minX + r.width * 0.44, y: r.minY + r.height * 0.34))
        tick.line(to: NSPoint(x: r.minX + r.width * 0.72, y: r.minY + r.height * 0.66))
        tick.lineWidth = 1.6
        tick.lineCapStyle = .round
        tick.lineJoinStyle = .round
        Theme.bg.setStroke()
        tick.stroke()
    }
}

extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

extension NSTextView {
    // true when the caret sits on the first (or last) visual line, so arrows can hop rows
    func caretOnLine(first: Bool) -> Bool {
        guard let layout = layoutManager, layout.numberOfGlyphs > 0 else { return true }
        let caret = min(selectedRange().location, layout.numberOfGlyphs - 1)
        let caretLine = layout.lineFragmentRect(forGlyphAt: layout.glyphIndexForCharacter(at: caret), effectiveRange: nil)
        let edge = layout.lineFragmentRect(forGlyphAt: first ? 0 : layout.numberOfGlyphs - 1, effectiveRange: nil)
        return caretLine.minY == edge.minY
    }
}
