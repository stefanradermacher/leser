import AppKit

// Draws the Leser app icon into the asset catalog and the document icon into Resources.
// Usage (from the project folder): swift scripts/make_icon.swift
// All drawing is done on a 1024 × 1024 canvas and scaled for the smaller sizes.

// MARK: helpers
func c(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: a)
}
func rr(_ r: NSRect, _ radius: CGFloat) -> NSBezierPath { NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius) }
var ctx: CGContext { NSGraphicsContext.current!.cgContext }
/// Output size relative to 1024; shadows are not affected by the scaled drawing, so they scale by hand.
var outputScale: CGFloat = 1
func shadow(_ blur: CGFloat, _ dy: CGFloat, _ alpha: CGFloat) {
    ctx.setShadow(offset: CGSize(width: 0, height: dy * outputScale), blur: blur * outputScale,
                  color: NSColor.black.withAlphaComponent(alpha).cgColor)
}
func noShadow() { ctx.setShadow(offset: .zero, blur: 0, color: nil) }

struct Style {
    var bgTop: NSColor, bgBottom: NSColor
    var accent: NSColor          // colour used on the page (headline, image)
    var image: (NSColor, NSColor, NSColor)  // sky, mountain far, mountain near
    var lens: NSColor            // ring colour
}

/// Squircle background on the macOS icon grid.
func background(_ s: Style) {
    let path = rr(NSRect(x: 100, y: 100, width: 824, height: 824), 185)
    NSGradient(starting: s.bgTop, ending: s.bgBottom)!.draw(in: path, angle: -90)
    // subtle top sheen
    ctx.saveGState(); path.addClip()
    NSGradient(starting: NSColor.white.withAlphaComponent(0.18), ending: NSColor.white.withAlphaComponent(0))!
        .draw(in: NSRect(x: 100, y: 600, width: 824, height: 324), angle: -90)
    ctx.restoreGState()
}

/// Page content: headline, picture across the left column, two text columns.
func pageContent(_ page: NSRect, _ s: Style) {
    let m: CGFloat = page.width * 0.1
    let inner = page.insetBy(dx: m, dy: m)
    let gap = inner.width * 0.08
    let colW = (inner.width - gap) / 2
    let line: CGFloat = inner.height * 0.028
    let step: CGFloat = inner.height * 0.058
    var top = inner.maxY

    // headline
    s.accent.setFill()
    rr(NSRect(x: inner.minX, y: top - line * 1.9, width: inner.width * 0.72, height: line * 1.9), line * 0.95).fill()
    top -= line * 1.9 + step * 0.9

    // picture in left column
    let picH = inner.height * 0.34
    let pic = NSRect(x: inner.minX, y: top - picH, width: colW, height: picH)
    ctx.saveGState(); rr(pic, colW * 0.06).addClip()
    s.image.0.setFill(); pic.fill()
    NSColor.white.withAlphaComponent(0.85).setFill()
    NSBezierPath(ovalIn: NSRect(x: pic.maxX - colW * 0.36, y: pic.maxY - picH * 0.42, width: colW * 0.2, height: colW * 0.2)).fill()
    let far = NSBezierPath(); far.move(to: NSPoint(x: pic.minX - 10, y: pic.minY))
    far.line(to: NSPoint(x: pic.minX + colW * 0.38, y: pic.minY + picH * 0.62))
    far.line(to: NSPoint(x: pic.minX + colW * 0.72, y: pic.minY + picH * 0.25))
    far.line(to: NSPoint(x: pic.maxX + 10, y: pic.minY)); far.close()
    s.image.1.setFill(); far.fill()
    let near = NSBezierPath(); near.move(to: NSPoint(x: pic.minX + colW * 0.3, y: pic.minY))
    near.line(to: NSPoint(x: pic.minX + colW * 0.7, y: pic.minY + picH * 0.45))
    near.line(to: NSPoint(x: pic.maxX + 10, y: pic.minY + picH * 0.12))
    near.line(to: NSPoint(x: pic.maxX + 10, y: pic.minY)); near.close()
    s.image.2.setFill(); near.fill()
    ctx.restoreGState()

    // text lines
    NSColor(white: 0.62, alpha: 1).setFill()
    let rightX = inner.minX + colW + gap
    var y = top - line
    var i = 0
    while y > inner.minY {
        let wR = colW * ([1, 0.92, 1, 0.8, 0.97, 1, 0.6][i % 7])
        rr(NSRect(x: rightX, y: y, width: wR, height: line), line / 2).fill()
        if y < pic.minY - step * 0.6 {
            let wL = colW * ([0.95, 1, 0.85, 1, 0.7][i % 5])
            rr(NSRect(x: inner.minX, y: y, width: wL, height: line), line / 2).fill()
        }
        y -= step; i += 1
    }
}

func page(_ r: NSRect, _ s: Style, fold: Bool = true, tilt: CGFloat = 0) {
    ctx.saveGState()
    if tilt != 0 {
        ctx.translateBy(x: r.midX, y: r.midY); ctx.rotate(by: tilt * .pi / 180); ctx.translateBy(x: -r.midX, y: -r.midY)
    }
    let foldSize = r.width * 0.2
    let p = NSBezierPath()
    p.move(to: NSPoint(x: r.minX, y: r.minY)); p.line(to: NSPoint(x: r.maxX, y: r.minY))
    if fold {
        p.line(to: NSPoint(x: r.maxX, y: r.maxY - foldSize)); p.line(to: NSPoint(x: r.maxX - foldSize, y: r.maxY))
    } else { p.line(to: NSPoint(x: r.maxX, y: r.maxY)) }
    p.line(to: NSPoint(x: r.minX, y: r.maxY)); p.close()
    shadow(34, -14, 0.35); NSColor(white: 0.99, alpha: 1).setFill(); p.fill(); noShadow()
    ctx.saveGState(); p.addClip(); pageContent(r, s); ctx.restoreGState()
    if fold {
        let f = NSBezierPath()
        f.move(to: NSPoint(x: r.maxX - foldSize, y: r.maxY)); f.line(to: NSPoint(x: r.maxX - foldSize, y: r.maxY - foldSize))
        f.line(to: NSPoint(x: r.maxX, y: r.maxY - foldSize)); f.close()
        shadow(10, -4, 0.25); NSColor(white: 0.84, alpha: 1).setFill(); f.fill(); noShadow()
    }
    ctx.restoreGState()
}

/// Magnifier over `target` on the page: the lens shows the page enlarged.
func magnifier(center: NSPoint, radius: CGFloat, page pr: NSRect, _ s: Style, zoom: CGFloat = 1.8, ringWidth: CGFloat = 0.16, handleColor: NSColor? = nil, handleAngle: CGFloat = 45) {
    // handle
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y); ctx.rotate(by: handleAngle * .pi / 180)
    let hw = radius * 0.42, hl = radius * 1.25
    let handle = rr(NSRect(x: -hw / 2, y: -radius - hl + radius * 0.08, width: hw, height: hl), hw / 2)
    shadow(20, -10, 0.35)
    NSGradient(starting: (handleColor ?? c(0x2B2B2E)).highlight(withLevel: 0.15)!, ending: handleColor ?? c(0x2B2B2E))!.draw(in: handle, angle: 0)
    noShadow()
    ctx.restoreGState()

    // lens content
    let lens = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    shadow(24, -10, 0.35); NSColor.white.setFill(); lens.fill(); noShadow()
    ctx.saveGState(); lens.addClip()
    NSColor(white: 0.99, alpha: 1).setFill(); lens.fill()
    ctx.translateBy(x: center.x, y: center.y); ctx.scaleBy(x: zoom, y: zoom); ctx.translateBy(x: -center.x, y: -center.y)
    pageContent(pr, s)
    ctx.restoreGState()
    // glass tint + highlight
    ctx.saveGState(); lens.addClip()
    NSGradient(starting: NSColor(white: 1, alpha: 0.28), ending: NSColor(white: 1, alpha: 0))!
        .draw(in: NSRect(x: center.x - radius, y: center.y, width: radius * 2, height: radius), angle: -90)
    ctx.restoreGState()
    // ring
    let ringW = radius * ringWidth
    let ring = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2).insetBy(dx: ringW / 2, dy: ringW / 2))
    ring.lineWidth = ringW
    s.lens.setStroke(); ring.stroke()
    let inner = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2).insetBy(dx: ringW, dy: ringW))
    inner.lineWidth = 3; NSColor.black.withAlphaComponent(0.15).setStroke(); inner.stroke()
}



let brick = Style(bgTop: c(0xC2473A), bgBottom: c(0x8F2A22), accent: c(0xA8362B),
                  image: (c(0xE9D3B8), c(0xC98B63), c(0x8C4A32)), lens: c(0x2B2B2E))

/// Blank page behind the front page, same shape.
func backPage(_ r: NSRect, shade: CGFloat) {
    let foldSize = r.width * 0.2
    let p = NSBezierPath()
    p.move(to: NSPoint(x: r.minX, y: r.minY)); p.line(to: NSPoint(x: r.maxX, y: r.minY))
    p.line(to: NSPoint(x: r.maxX, y: r.maxY - foldSize)); p.line(to: NSPoint(x: r.maxX - foldSize, y: r.maxY))
    p.line(to: NSPoint(x: r.minX, y: r.maxY)); p.close()
    shadow(22, -8, 0.3); NSColor(white: shade, alpha: 1).setFill(); p.fill(); noShadow()
}

/// A stack of `count` pages, offset by `step`, centered on the icon. Returns the front page.
func stack(count: Int, size: NSSize, step: NSPoint) -> NSRect {
    let total = NSSize(width: size.width + abs(step.x) * CGFloat(count - 1), height: size.height + abs(step.y) * CGFloat(count - 1))
    let origin = NSPoint(x: 512 - total.width / 2, y: 512 - total.height / 2)
    // back pages lie up and to the right of the front page
    for i in stride(from: count - 1, to: 0, by: -1) {
        let r = NSRect(x: origin.x + step.x * CGFloat(i), y: origin.y + step.y * CGFloat(i), width: size.width, height: size.height)
        backPage(r, shade: 0.93 - CGFloat(i) * 0.04)
    }
    return NSRect(origin: origin, size: size)
}


/// The document icon: the front page of the stack, filling the icon,
/// with a large brick red folded corner.
func drawDocumentIcon() {
    let r = NSRect(x: 142, y: 40, width: 740, height: 950)
    let fold = r.width * 0.27
    let page = NSBezierPath()
    page.move(to: NSPoint(x: r.minX, y: r.minY)); page.line(to: NSPoint(x: r.maxX, y: r.minY))
    page.line(to: NSPoint(x: r.maxX, y: r.maxY - fold)); page.line(to: NSPoint(x: r.maxX - fold, y: r.maxY))
    page.line(to: NSPoint(x: r.minX, y: r.maxY)); page.close()
    shadow(34, -14, 0.34); NSColor.white.setFill(); page.fill(); noShadow()

    ctx.saveGState(); page.addClip(); pageContent(r, brick); ctx.restoreGState()

    let corner = NSBezierPath()
    corner.move(to: NSPoint(x: r.maxX - fold, y: r.maxY)); corner.line(to: NSPoint(x: r.maxX - fold, y: r.maxY - fold))
    corner.line(to: NSPoint(x: r.maxX, y: r.maxY - fold)); corner.close()
    shadow(12, -5, 0.22); c(0xB03A2E).setFill(); corner.fill(); noShadow()
}

/// Three stacked pages with a two-column layout and a picture, and a magnifier held from the right.
func drawIcon() {
    background(brick)
    let front = stack(count: 3, size: NSSize(width: 430, height: 590), step: NSPoint(x: 26, y: 26))
    page(front, brick)
    magnifier(center: NSPoint(x: front.maxX - 90, y: front.minY + 190), radius: 150, page: front, brick, handleAngle: 45)
}

let out = URL(fileURLWithPath: "Resources/Assets.xcassets/AppIcon.appiconset")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func png(_ px: Int, _ draw: () -> Void = drawIcon) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    outputScale = CGFloat(px) / 1024
    ctx.scaleBy(x: outputScale, y: outputScale)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

var images: [String] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try! png(size * scale).write(to: out.appendingPathComponent(name))
        images.append("""
            { "filename" : "\(name)", "idiom" : "mac", "scale" : "\(scale)x", "size" : "\(size)x\(size)" }
        """)
    }
}
// Document icon as .icns next to the app icon
let docSet = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DocumentIcon.iconset")
try? FileManager.default.removeItem(at: docSet)
try! FileManager.default.createDirectory(at: docSet, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    try! png(size, drawDocumentIcon).write(to: docSet.appendingPathComponent("icon_\(size)x\(size).png"))
    try! png(size * 2, drawDocumentIcon).write(to: docSet.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", docSet.path, "-o", "Resources/PDFDocument.icns"]
try! iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: docSet)

let contents = """
{
  "images" : [
\(images.joined(separator: ",\n"))
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}

"""
try! contents.write(to: out.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
