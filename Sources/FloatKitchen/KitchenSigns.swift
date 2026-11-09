import AppKit
import KitchenCore

/// Static AppKit text is deliberately outside the animated layer-hosting view.
final class KitchenSigns: NSView {
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    private var events: [KitchenEvent?] = []
    private var clients: [String] = []
    private var demo = true
    func update(_ events: [KitchenEvent?], clients: [String], demo: Bool) {
        self.events = events; self.clients = clients; self.demo = demo; needsDisplay = true
    }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        guard events.count == 3 else { return }
        let compact = bounds.width < 500
        for i in 0..<3 {
            let x = bounds.width*[0.31, 0.53, 0.75][i]
            let rect = NSRect(x: x-bounds.width*0.102, y: bounds.height*0.84, width: bounds.width*0.204, height: max(30, bounds.height*0.085))
            Bistro.round(rect, radius: 5, color: Bistro.paper)
            let event = events[i]
            let activity: KitchenActivity = (!demo && Date().timeIntervalSince(event?.date ?? .distantPast) > 120) ? .idle : (event?.activity ?? .idle)
            let title = "\(clients[i] == "Local" ? "自定义" : clients[i])  \(activity.meaning)"
            let detail = activity == .idle ? "等待新任务" : (event?.detail.isEmpty == false ? event!.detail : (event?.tool.isEmpty == false ? event!.tool : "等待事件"))
            let width = rect.width-10
            let titleSize: CGFloat = compact ? 7.5 : 9
            let detailSize: CGFloat = compact ? 7 : 8
            Bistro.text(Bistro.fitted(title, width: width, font: Bistro.font(titleSize, .semibold)), NSRect(x: rect.minX+5, y: rect.minY+4, width: width, height: 13), size: titleSize, color: Bistro.ink, weight: .semibold, align: .center)
            Bistro.text(Bistro.fitted(detail, width: width, font: Bistro.font(detailSize)), NSRect(x: rect.minX+5, y: rect.minY+18, width: width, height: 12), size: detailSize, color: Bistro.ink, align: .center)
        }
    }
}
