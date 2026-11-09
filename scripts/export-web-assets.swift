import AppKit
import ImageIO
import UniformTypeIdentifiers
let source = CommandLine.arguments[1], output = CommandLine.arguments[2]
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
let image = NSImage(contentsOfFile: source)!
var proposed = CGRect(origin: .zero, size: image.size)
let atlas = image.cgImage(forProposedRect: &proposed, context: nil, hints: nil)!
let names = ["reading", "searching", "cooking", "testing", "waiting", "failed", "served", "idle"]
for (index,name) in names.enumerated() {
 let rect = CGRect(x: CGFloat(index%4)*CGFloat(atlas.width)/4, y: CGFloat(index/4)*CGFloat(atlas.height)/2, width: CGFloat(atlas.width)/4, height: CGFloat(atlas.height)/2).integral
 let crop = atlas.cropping(to: rect)!
 let file = URL(fileURLWithPath: output).appendingPathComponent("chef-\(name).png")
 let destination = CGImageDestinationCreateWithURL(file as CFURL, UTType.png.identifier as CFString, 1, nil)!
 CGImageDestinationAddImage(destination, crop, nil); CGImageDestinationFinalize(destination)
}
