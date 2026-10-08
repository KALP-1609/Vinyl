// Generates the app icon (a vinyl record on a purple tile) as an .iconset folder.
// Usage: swift scripts/make_icon.swift <output.iconset>
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func png(size px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)

    // Tile
    let inset = s * 0.1
    let tile = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: s * 0.18, yRadius: s * 0.18)
    NSGradient(colors: [NSColor(calibratedRed: 0.58, green: 0.36, blue: 0.96, alpha: 1),
                        NSColor(calibratedRed: 0.10, green: 0.06, blue: 0.26, alpha: 1)])!
        .draw(in: tilePath, angle: -60)

    // Record
    let c = CGPoint(x: s * 0.46, y: s * 0.46)
    let r = s * 0.30
    func oval(_ rad: CGFloat) -> NSBezierPath {
        NSBezierPath(ovalIn: NSRect(x: c.x - rad, y: c.y - rad, width: rad * 2, height: rad * 2))
    }
    NSColor(white: 0.06, alpha: 1).setFill()
    oval(r).fill()
    NSColor(white: 1, alpha: 0.08).setStroke()
    for i in 1...5 {
        let p = oval(r * (0.45 + CGFloat(i) * 0.1))
        p.lineWidth = max(1, s * 0.003)
        p.stroke()
    }
    NSGradient(colors: [NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.35, alpha: 1),
                        NSColor(calibratedRed: 0.95, green: 0.30, blue: 0.55, alpha: 1)])!
        .draw(in: oval(r * 0.38), angle: 45)
    NSColor(white: 0.05, alpha: 1).setFill()
    oval(r * 0.06).fill()

    // Tonearm
    let pivot = CGPoint(x: s * 0.74, y: s * 0.78)
    let tip = CGPoint(x: s * 0.58, y: s * 0.52)
    let arm = NSBezierPath()
    arm.move(to: pivot)
    arm.line(to: tip)
    arm.lineWidth = s * 0.018
    arm.lineCapStyle = .round
    NSColor(white: 0.93, alpha: 1).setStroke()
    arm.stroke()
    NSColor(white: 0.88, alpha: 1).setFill()
    let pr = s * 0.04
    NSBezierPath(ovalIn: NSRect(x: pivot.x - pr, y: pivot.y - pr, width: pr * 2, height: pr * 2)).fill()

    // Soft gloss on the tile
    NSGradient(colors: [NSColor(white: 1, alpha: 0.22), NSColor(white: 1, alpha: 0)])!
        .draw(in: tilePath, angle: -75)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let files: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, px) in files {
    try png(size: px).write(to: URL(fileURLWithPath: outDir).appendingPathComponent(name))
}
