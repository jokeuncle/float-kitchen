import AppKit
let source = CommandLine.arguments[1]
let destination = CommandLine.arguments[2]
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
NSColor(srgbRed: 0.13, green: 0.114, blue: 0.098, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 25, y: 25, width: 974, height: 974), xRadius: 220, yRadius: 220).fill()
if let chefs = NSImage(contentsOfFile: source) {
    let third = chefs.size.width/3
    chefs.draw(in: NSRect(x: 214, y: 62, width: 596, height: 1090), from: NSRect(x: third, y: 0, width: third, height: chefs.size.height), operation: .sourceOver, fraction: 1)
}
image.unlockFocus()
let data = NSBitmapImageRep(data: image.tiffRepresentation!)!.representation(using: .png, properties: [:])!
try data.write(to: URL(fileURLWithPath: destination))
