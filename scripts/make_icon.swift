// Renders assets/AppIcon.icns: two overlapping displays on a blue rounded square.
// The back display is cut around the front one, so the two never merge.
// Usage: swift scripts/make_icon.swift assets/AppIcon.icns
import AppKit

let out = CommandLine.arguments.dropFirst().first ?? "assets/AppIcon.icns"
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

/// Monitor geometry in a 1024-unit space: bezel rect, screen inset, neck and base.
struct Monitor {
    let bezel: NSRect
    var radius: CGFloat { bezel.height * 0.09 }
    var screen: NSRect { bezel.insetBy(dx: bezel.width * 0.075, dy: bezel.width * 0.075) }
    var neck: NSRect {
        NSRect(x: bezel.midX - bezel.width * 0.07, y: bezel.minY - bezel.height * 0.16,
               width: bezel.width * 0.14, height: bezel.height * 0.16 + 2)
    }
    var base: NSRect {
        NSRect(x: bezel.midX - bezel.width * 0.2, y: neck.minY - bezel.height * 0.075,
               width: bezel.width * 0.4, height: bezel.height * 0.075)
    }

    /// Whole silhouette (bezel + neck + base).
    func silhouette() -> NSBezierPath {
        let p = NSBezierPath(roundedRect: bezel, xRadius: radius, yRadius: radius)
        p.append(NSBezierPath(rect: neck))
        p.append(NSBezierPath(roundedRect: base, xRadius: base.height / 2, yRadius: base.height / 2))
        return p
    }

    func draw() {
        NSColor.white.setFill()
        silhouette().fill()
        let r = radius * 0.55
        NSGradient(starting: NSColor(calibratedRed: 0.62, green: 0.82, blue: 1.0, alpha: 1),
                   ending: NSColor(calibratedRed: 0.36, green: 0.62, blue: 0.98, alpha: 1))!
            .draw(in: NSBezierPath(roundedRect: screen, xRadius: r, yRadius: r), angle: -90)
    }
}

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let scale = CGFloat(px) / 1024
    NSAffineTransform(transform: AffineTransform(scale: scale)).concat()

    // macOS icon grid: 824-unit body with ~185-unit corner radius.
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let bg = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
    NSGradient(starting: NSColor(calibratedRed: 0.20, green: 0.55, blue: 1.0, alpha: 1),
               ending: NSColor(calibratedRed: 0.10, green: 0.20, blue: 0.62, alpha: 1))!.draw(in: bg, angle: -90)

    let back = Monitor(bezel: NSRect(x: 138, y: 450, width: 440, height: 300))
    let front = Monitor(bezel: NSRect(x: 478, y: 310, width: 396, height: 268))

    // Back display, clipped so a gap of background shows around the front one.
    NSGraphicsContext.saveGraphicsState()
    let gap: CGFloat = 26
    let cutout = NSBezierPath(rect: body)
    let outline = NSBezierPath(roundedRect: front.bezel.insetBy(dx: -gap, dy: -gap),
                               xRadius: front.radius + gap, yRadius: front.radius + gap)
    cutout.append(outline)
    let neckBase = NSBezierPath(rect: front.neck.insetBy(dx: -gap, dy: 0))
    neckBase.append(NSBezierPath(rect: front.base.insetBy(dx: -gap, dy: -gap)))
    cutout.append(neckBase)
    cutout.windingRule = .evenOdd
    cutout.addClip()
    back.draw()
    NSGraphicsContext.restoreGraphicsState()

    front.draw()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", out]
try! task.run()
task.waitUntilExit()
exit(task.terminationStatus)
