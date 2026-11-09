import AppKit

final class BistroButton: NSButton {
    var active = false { didSet { needsDisplay = true } }
    var icon: String?
    var quiet = false
    private var hovering = false
    private var tracking: NSTrackingArea?
    init(_ title: String, icon: String? = nil, target: AnyObject?, action: Selector) {
        super.init(frame: .zero)
        self.title = title; self.icon = icon; self.target = target; self.action = action
        isBordered = false; bezelStyle = .rounded; setButtonType(.momentaryPushIn)
        setAccessibilityLabel(title); font = Bistro.font(12, .medium)
        focusRingType = .exterior
    }
    required init?(coder: NSCoder) { fatalError() }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        tracking = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(tracking!)
    }
    override func mouseEntered(with event: NSEvent) { hovering = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hovering = false; needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        let background = active ? Bistro.copper : Bistro.surface
        if !quiet || hovering || active { Bistro.round(bounds.insetBy(dx: 1, dy: 1), radius: 9, color: background.withAlphaComponent(isHighlighted ? 0.65 : (hovering ? 1 : 0.85))) }
        let color = !isEnabled ? Bistro.muted : (active ? Bistro.ink : (hovering ? Bistro.cream : Bistro.secondary))
        if let icon, !title.isEmpty {
            Bistro.iconText(icon, title, in: bounds.insetBy(dx: 8, dy: 2), size: 12, color: color, weight: .medium, centered: true, iconSize: 14)
        } else if let icon {
            Bistro.symbol(icon, in: NSRect(x: (bounds.width-15)/2, y: (bounds.height-15)/2, width: 15, height: 15), color: color)
        } else if !title.isEmpty {
            let height = Bistro.font(12, .medium).ascender-Bistro.font(12, .medium).descender
            Bistro.text(title, NSRect(x: 3, y: (bounds.height-height)/2, width: bounds.width-6, height: height), size: 12, color: color, weight: .medium, align: .center)
        }
        if window?.firstResponder === self {
            Bistro.sage.setStroke(); let p = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 8, yRadius: 8); p.lineWidth = 2; p.stroke()
        }
    }
}
