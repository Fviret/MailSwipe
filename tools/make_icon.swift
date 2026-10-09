// Génère l'icône 1024x1024 : swift tools/make_icon.swift Sources/Assets.xcassets/AppIcon.appiconset/icon.png
import AppKit

let size: CGFloat = 1024
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
    samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 32
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// Fond : dégradé indigo -> violet
let colors = [NSColor(red: 0.27, green: 0.30, blue: 0.93, alpha: 1).cgColor, NSColor(red: 0.62, green: 0.25, blue: 0.86, alpha: 1).cgColor]
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])

func card(rotation: CGFloat, alpha: CGFloat, offsetX: CGFloat, offsetY: CGFloat) {
    ctx.saveGState()
    ctx.translateBy(x: size / 2 + offsetX, y: size / 2 + offsetY)
    ctx.rotate(by: rotation)
    let rect = CGRect(x: -270, y: -200, width: 540, height: 400)
    let path = CGPath(roundedRect: rect, cornerWidth: 56, cornerHeight: 56, transform: nil)
    ctx.setShadow(offset: CGSize(width: 0, height: -24), blur: 48, color: NSColor.black.withAlphaComponent(0.28).cgColor)
    ctx.setFillColor(NSColor.white.withAlphaComponent(alpha).cgColor)
    ctx.addPath(path)
    ctx.fillPath()
    ctx.restoreGState()
}

card(rotation: 0.16, alpha: 0.38, offsetX: -30, offsetY: 40)
card(rotation: -0.10, alpha: 1.0, offsetX: 10, offsetY: -10)

// Enveloppe sur la carte du dessus
ctx.saveGState()
ctx.translateBy(x: size / 2 + 10, y: size / 2 - 10)
ctx.rotate(by: -0.10)
ctx.setStrokeColor(NSColor(red: 0.37, green: 0.28, blue: 0.90, alpha: 1).cgColor)
ctx.setLineWidth(30)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.move(to: CGPoint(x: -170, y: 90))
ctx.addLine(to: CGPoint(x: 0, y: -40))
ctx.addLine(to: CGPoint(x: 170, y: 90))
ctx.strokePath()
ctx.restoreGState()

NSGraphicsContext.restoreGraphicsState()
let data = rep.representation(using: .png, properties: [:])!
try! data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
