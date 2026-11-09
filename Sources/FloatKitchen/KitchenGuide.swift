import AppKit
import KitchenCore

final class KitchenGuideView: NSView {
    override var isFlipped: Bool { true }
    let activities: [KitchenActivity] = [.reading, .searching, .cooking, .testing, .waiting, .failed, .served, .idle]
    var onDemonstrate: ((KitchenActivity) -> Void)?
    private var thumbnails: [NSImage] = []
    override init(frame: NSRect) {
        super.init(frame: frame)
        if let atlas = KitchenStage.load("chef-states") {
            for index in 0..<8 {
                let rect = CGRect(x: CGFloat(index%4)*CGFloat(atlas.width)/4, y: CGFloat(index/4)*CGFloat(atlas.height)/2, width: CGFloat(atlas.width)/4, height: CGFloat(atlas.height)/2)
                if let cg = atlas.cropping(to: rect) { thumbnails.append(NSImage(cgImage: cg, size: NSSize(width: 75, height: 100))) }
            }
        }
        for (index, activity) in activities.enumerated() {
            let button = BistroButton("看此动作", icon: "play", target: self, action: #selector(play(_:)))
            button.tag = index; button.frame = NSRect(x: 452, y: 136+CGFloat(index)*120, width: 100, height: 32)
            button.setAccessibilityLabel("演示：" + activity.meaning); addSubview(button)
        }
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        Bistro.background.setFill(); bounds.fill()
        Bistro.text("看懂后厨", NSRect(x: 28, y: 24, width: 500, height: 40), size: 28, color: Bistro.cream, weight: .medium, serif: true)
        Bistro.text("每个动作，都有对应的真实活动。", NSRect(x: 30, y: 70, width: 500, height: 22), size: 14, color: Bistro.secondary)
        Bistro.text("点「看此动作」会切到演示，并在厨房保留该动作；点「看场好戏」恢复连续演示。", NSRect(x: 30, y: 97, width: 530, height: 35), size: 11, color: Bistro.muted)
        for (index, activity) in activities.enumerated() {
            let y: CGFloat = 140+CGFloat(index)*120
            Bistro.line(NSPoint(x: 28, y: y-10), NSPoint(x: 553, y: y-10))
            if thumbnails.count == 8 { thumbnails[index].draw(in: NSRect(x: 22, y: y-2, width: 68, height: 91), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil) }
            Bistro.text(activity.meaning + " / " + activity.short, NSRect(x: 102, y: y, width: 342, height: 24), size: 15, color: Bistro.cream, weight: .semibold)
            drawWrapped(activity.motionDescription, rect: NSRect(x: 102, y: y+29, width: 438, height: 23), color: Bistro.copper)
            drawWrapped(activity.evidenceDescription, rect: NSRect(x: 102, y: y+56, width: 438, height: 48), color: Bistro.secondary)
        }
    }
    private func drawWrapped(_ text: String, rect: NSRect, color: NSColor) {
        let paragraph = NSMutableParagraphStyle(); paragraph.lineBreakMode = .byWordWrapping; paragraph.lineSpacing = 3
        (text as NSString).draw(in: rect, withAttributes: [.font: Bistro.font(11), .foregroundColor: color, .paragraphStyle: paragraph])
    }
    @objc private func play(_ sender: NSButton) { onDemonstrate?(activities[sender.tag]) }
}
