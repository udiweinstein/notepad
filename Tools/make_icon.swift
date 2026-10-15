// Draws the app icon into an .iconset folder: swift Tools/make_icon.swift build/AppIcon.iconset
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let u = CGFloat(px) / 1024

    // Page with soft shadow
    let page = NSRect(x: 172 * u, y: 96 * u, width: 680 * u, height: 820 * u)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowBlurRadius = 28 * u
    shadow.shadowOffset = NSSize(width: 0, height: -12 * u)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSColor(calibratedWhite: 0.99, alpha: 1).setFill()
    NSBezierPath(roundedRect: page, xRadius: 56 * u, yRadius: 56 * u).fill()
    NSGraphicsContext.restoreGraphicsState()

    // Blue header band
    let clip = NSBezierPath(roundedRect: page, xRadius: 56 * u, yRadius: 56 * u)
    NSGraphicsContext.saveGraphicsState()
    clip.addClip()
    NSColor(calibratedRed: 0.13, green: 0.47, blue: 0.93, alpha: 1).setFill()
    NSRect(x: page.minX, y: page.maxY - 170 * u, width: page.width, height: 170 * u).fill()
    NSGraphicsContext.restoreGraphicsState()

    // Ruled lines
    NSColor(calibratedRed: 0.62, green: 0.74, blue: 0.92, alpha: 1).setFill()
    var y = page.maxY - 260 * u
    var index = 0
    while y > page.minY + 70 * u {
        let width = (index % 3 == 2 ? 0.55 : 0.8) * (page.width - 160 * u)
        NSBezierPath(roundedRect: NSRect(x: page.minX + 80 * u, y: y, width: width, height: 22 * u),
                     xRadius: 11 * u, yRadius: 11 * u).fill()
        y -= 92 * u
        index += 1
    }

    // Spiral rings
    for i in 0..<5 {
        let x = page.minX + 110 * u + CGFloat(i) * 115 * u
        let ring = NSRect(x: x, y: page.maxY - 60 * u, width: 50 * u, height: 110 * u)
        NSColor(calibratedWhite: 0.25, alpha: 1).setStroke()
        let path = NSBezierPath(roundedRect: ring, xRadius: 25 * u, yRadius: 25 * u)
        path.lineWidth = 16 * u
        path.stroke()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let sizes: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in sizes {
    try! render(px).write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
}
