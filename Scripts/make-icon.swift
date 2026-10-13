// Renders the app icon: swift Scripts/make-icon.swift <output.png>
import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let bg = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
NSGradient(starting: NSColor(srgbRed: 0.16, green: 0.17, blue: 0.20, alpha: 1),
           ending: NSColor(srgbRed: 0.06, green: 0.07, blue: 0.09, alpha: 1))!.draw(in: bg, angle: -90)

// Ruler body, rotated 45°.
let ctx = NSGraphicsContext.current!.cgContext
ctx.saveGState()
ctx.translateBy(x: 512, y: 512)
ctx.rotate(by: .pi / 4)
let ruler = NSRect(x: -380, y: -110, width: 760, height: 220)
NSColor(srgbRed: 1.0, green: 0.31, blue: 0.0, alpha: 1).setFill()
NSBezierPath(roundedRect: ruler, xRadius: 28, yRadius: 28).fill()
NSColor(white: 0.08, alpha: 1).setFill()
for i in 0...18 {
    let x = ruler.minX + 40 + CGFloat(i) * 38
    let h: CGFloat = i % 5 == 0 ? 110 : 60
    NSRect(x: x - 5, y: ruler.maxY - h, width: 10, height: h).fill()
}
ctx.restoreGState()

image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
