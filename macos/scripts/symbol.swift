// App-Symbol zeichnen: Briefumschlag auf gelbem Verlauf im macOS-Stil, dazu eine blaue Glocke (angekündigt).
// Aufruf: swift scripts/symbol.swift <Ordner.iconset>
import AppKit

let ordner = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: ordner, withIntermediateDirectories: true)

func bild(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    let rand = s * 0.1
    let flaeche = NSRect(x: rand, y: rand, width: s - 2 * rand, height: s - 2 * rand)
    let form = NSBezierPath(roundedRect: flaeche, xRadius: flaeche.width * 0.225, yRadius: flaeche.width * 0.225)
    NSGraphicsContext.current?.saveGraphicsState()
    let schatten = NSShadow()
    schatten.shadowColor = NSColor.black.withAlphaComponent(0.3)
    schatten.shadowOffset = NSSize(width: 0, height: -s * 0.01)
    schatten.shadowBlurRadius = s * 0.025
    schatten.set()
    NSGradient(colors: [NSColor(red: 1.0, green: 0.84, blue: 0.25, alpha: 1), NSColor(red: 0.96, green: 0.66, blue: 0.0, alpha: 1)])!
        .draw(in: form, angle: -90)
    NSGraphicsContext.current?.restoreGraphicsState()
    // heller Schein oben (Glas)
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.35), NSColor.white.withAlphaComponent(0)])!
        .draw(in: NSBezierPath(roundedRect: flaeche.insetBy(dx: s * 0.01, dy: s * 0.01), xRadius: flaeche.width * 0.215, yRadius: flaeche.width * 0.215), angle: -90)
    let konfig = NSImage.SymbolConfiguration(pointSize: s * 0.36, weight: .semibold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor(red: 0.17, green: 0.15, blue: 0.09, alpha: 1)]))
    if let sym = NSImage(systemSymbolName: "envelope.fill", accessibilityDescription: nil)?.withSymbolConfiguration(konfig) {
        let g = sym.size
        let r = NSRect(x: (s - g.width) / 2 - s * 0.02, y: (s - g.height) / 2 - s * 0.03, width: g.width, height: g.height)
        sym.draw(in: r)
    }
    // Glocke im blauen Kreis oben rechts
    let kreis = NSRect(x: s * 0.6, y: s * 0.56, width: s * 0.26, height: s * 0.26)
    NSColor(red: 0.17, green: 0.15, blue: 0.09, alpha: 1).setFill()
    NSBezierPath(ovalIn: kreis.insetBy(dx: -s * 0.018, dy: -s * 0.018)).fill()
    NSColor(red: 0.18, green: 0.49, blue: 0.96, alpha: 1).setFill()
    NSBezierPath(ovalIn: kreis).fill()
    let glocke = NSImage.SymbolConfiguration(pointSize: s * 0.13, weight: .bold).applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    if let b = NSImage(systemSymbolName: "bell.fill", accessibilityDescription: nil)?.withSymbolConfiguration(glocke) {
        let g = b.size
        b.draw(in: NSRect(x: kreis.midX - g.width / 2, y: kreis.midY - g.height / 2, width: g.width, height: g.height))
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for (groesse, faktor) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let name = faktor == 1 ? "icon_\(groesse)x\(groesse).png" : "icon_\(groesse)x\(groesse)@2x.png"
    try! bild(groesse * faktor).write(to: URL(fileURLWithPath: "\(ordner)/\(name)"))
}
