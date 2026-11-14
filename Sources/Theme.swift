import AppKit

enum Theme {
    static let width: CGFloat = 320
    static let fieldWidth: CGFloat = 246
    static let maxListHeight: CGFloat = 440

    static let font = NSFont.systemFont(ofSize: 13.5)
    static let small = NSFont.systemFont(ofSize: 11.5)

    static let bg = NSColor(srgbRed: 0.105, green: 0.105, blue: 0.115, alpha: 1)
    static let border = NSColor(white: 1, alpha: 0.09)
    static let line = NSColor(white: 1, alpha: 0.06)
    static let text = NSColor(white: 0.93, alpha: 1)
    static let dim = NSColor(white: 1, alpha: 0.34)
    static let faint = NSColor(white: 1, alpha: 0.26)
    static let check = NSColor(white: 0.86, alpha: 1)
}

final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

final class FirstMouseButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
