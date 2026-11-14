import AppKit

// draws the 1024px app icon: dark squircle with a light check circle
let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
    let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
    NSColor(srgbRed: 0.105, green: 0.105, blue: 0.115, alpha: 1).setFill()
    NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185).fill()
    NSColor(white: 1, alpha: 0.09).setStroke()
    let edge = NSBezierPath(roundedRect: tile.insetBy(dx: 2, dy: 2), xRadius: 183, yRadius: 183)
    edge.lineWidth = 4
    edge.stroke()

    let circle = NSRect(x: 312, y: 312, width: 400, height: 400)
    NSColor(white: 0.9, alpha: 1).setFill()
    NSBezierPath(ovalIn: circle).fill()
    let tick = NSBezierPath()
    tick.move(to: NSPoint(x: 420, y: 512))
    tick.line(to: NSPoint(x: 487, y: 445))
    tick.line(to: NSPoint(x: 610, y: 580))
    tick.lineWidth = 38
    tick.lineCapStyle = .round
    tick.lineJoinStyle = .round
    NSColor(srgbRed: 0.105, green: 0.105, blue: 0.115, alpha: 1).setStroke()
    tick.stroke()
    return true
}
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
