import AppKit
import KitchenCore

final class KitchenView: NSView {
    override var isFlipped: Bool { true }
    let model: KitchenModel
    let stage = KitchenStage(frame: .zero)
    let signs = KitchenSigns(frame: .zero)
    var compact = false { didSet { needsLayout = true; refresh() } }
    var pinned = true { didSet { pin.active = pinned } }
    var onPin: (() -> Void)?
    var onCompact: (() -> Void)?
    var onHide: (() -> Void)?
    var onConnect: (() -> Void)?
    var onOrder: (() -> Void)?
    var onGuide: (() -> Void)?
    var sleeping = false { didSet { refresh() } }
    private var pin: BistroButton!
    private var fold: BistroButton!
    private var hide: BistroButton!
    private var live: BistroButton!
    private var demo: BistroButton!
    private var pause: BistroButton!
    private var connect: BistroButton!
    private var receipt: BistroButton!
    private var guide: BistroButton!
    private var clients: [BistroButton] = []
    private var tracking: NSTrackingArea?
    init(frame: NSRect, model: KitchenModel) {
        self.model = model
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 24; layer?.masksToBounds = true
        setAccessibilityLabel("Float Kitchen，AI 后厨")
        addSubview(stage)
        addSubview(signs)
        pin = button("", icon: "pin.fill", action: #selector(pinClick)); pin.toolTip = "切换置顶"; pin.setAccessibilityLabel("切换置顶")
        fold = button("", icon: "arrow.down.right.and.arrow.up.left", action: #selector(foldClick)); fold.toolTip = "切换迷你厨房"; fold.setAccessibilityLabel("切换迷你厨房")
        hide = button("", icon: "xmark", action: #selector(hideClick)); hide.toolTip = "隐藏，可从菜单栏找回"; hide.setAccessibilityLabel("隐藏厨房")
        for control in [pin, fold, hide] { control?.quiet = true }
        live = button("真实活动", icon: "waveform.path", action: #selector(liveClick))
        demo = button("看场好戏", icon: "play", action: #selector(demoClick))
        pause = button("", icon: "pause", action: #selector(pauseClick)); pause.toolTip = "暂停或继续演示"; pause.setAccessibilityLabel("暂停或继续演示")
        connect = button("接入事件", icon: "link", action: #selector(connectClick))
        receipt = button("订单小票", icon: "receipt", action: #selector(orderClick))
        guide = button("看懂后厨", icon: "questionmark.circle", action: #selector(guideClick))
        for (i, client) in model.clients.enumerated() {
            let control = button(client == "Local" ? "自定义" : client, icon: nil, action: #selector(clientClick(_:)))
            control.tag = i; clients.append(control)
        }
        stage.onSelect = { [weak self] index in self?.select(index) }
        refresh()
    }
    required init?(coder: NSCoder) { fatalError() }
    private func button(_ title: String, icon: String?, action: Selector) -> BistroButton {
        let b = BistroButton(title, icon: icon, target: self, action: action); addSubview(b); return b
    }
    override func layout() {
        super.layout()
        let width = bounds.width
        pin.frame = NSRect(x: width-116, y: 22, width: 30, height: 30)
        fold.frame = NSRect(x: width-82, y: 22, width: 30, height: 30)
        hide.frame = NSRect(x: width-48, y: 22, width: 30, height: 30)
        live.frame = NSRect(x: 24, y: 82, width: 110, height: 30)
        demo.frame = NSRect(x: 140, y: 82, width: 110, height: 30)
        pause.frame = NSRect(x: 258, y: 82, width: 30, height: 30)
        connect.frame = NSRect(x: width-126, y: 82, width: 102, height: 30)
        receipt.frame = NSRect(x: width-130, y: 600, width: 102, height: 30)
        guide.frame = NSRect(x: width-130, y: 724, width: 102, height: 30)
        stage.frame = NSRect(x: 12, y: compact ? 66 : 122, width: width-24, height: (width-24)/1.5)
        signs.frame = stage.frame
        for (i, button) in clients.enumerated() { button.frame = NSRect(x: 28 + CGFloat(i)*92, y: 600, width: 84, height: 30) }
        for view in [live, demo, pause, connect, receipt, guide] + clients { view?.isHidden = compact }
        stage.needsLayout = true
    }
    func refresh() {
        live?.active = !model.demo; demo?.active = model.demo
        pause?.isHidden = !model.demo || compact
        pause?.icon = model.paused ? "play" : "pause"; pause?.needsDisplay = true
        pin?.active = pinned
        for (i, button) in clients.enumerated() { button.active = model.clients[i] == model.selectedClient }
        let states = model.clients.map { client -> KitchenActivity in
            guard let event = model.states[client], model.demo || Date().timeIntervalSince(event.date) < 120 else { return .idle }
            return event.activity
        }
        stage.setStates(states, paused: model.paused || sleeping || isHidden || window?.isVisible == false)
        signs.update(model.clients.map { model.states[$0] }, clients: model.clients, demo: model.demo)
        setAccessibilityValue("\(model.demo ? "演示" : "真实活动")，\(model.selectedClient)，\(model.activity.caption)")
        needsDisplay = true
    }
    override func draw(_ dirtyRect: NSRect) {
        Bistro.round(bounds, radius: 24, color: Bistro.background)
        Bistro.rule.setStroke(); let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 24, yRadius: 24); border.lineWidth = 1; border.stroke()
        Bistro.iconText("frying.pan", "Float Kitchen", in: NSRect(x: 28, y: 17, width: bounds.width-160, height: 44), size: compact ? 23 : 28, color: Bistro.cream, iconColor: Bistro.copper, weight: .medium, serif: true, iconSize: 24)
        if compact {
            Bistro.text(model.activity.caption, NSRect(x: 25, y: bounds.height-41, width: bounds.width-112, height: 24), size: 13, color: model.activity.tint)
            Bistro.text(model.demo ? "演示中" : "真实活动", NSRect(x: bounds.width-91, y: bounds.height-40, width: 68, height: 22), size: 11, color: Bistro.secondary, align: .right)
            return
        }
        Bistro.text("把等待，煮成好时光。", NSRect(x: 28, y: 60, width: 300, height: 20), size: 12, color: Bistro.secondary)
        let activity = model.activity
        Bistro.iconText(activity.symbol, activity.caption, in: NSRect(x: 29, y: 554, width: bounds.width-58, height: 38), size: 20, color: Bistro.cream, iconColor: activity.tint, weight: .medium, serif: true)
        let status = model.demo ? "虚构任务演示中" : (model.events.isEmpty ? "等一份新订单" : "本地事件驱动")
        Bistro.text(status, NSRect(x: 316, y: 607, width: bounds.width-460, height: 20), size: 11, color: Bistro.secondary, align: .right)
        Bistro.line(NSPoint(x: 28, y: 644), NSPoint(x: bounds.width-28, y: 644))
        if model.events.isEmpty {
            Bistro.text("厨房已经就绪。让 Codex 或 Claude 开始工作吧。", NSRect(x: 30, y: 657, width: bounds.width-60, height: 24), size: 12, color: Bistro.secondary)
            Bistro.text("也可通过「接入事件」连接自定义客户端。", NSRect(x: 30, y: 680, width: bounds.width-60, height: 24), size: 11, color: Bistro.muted)
        } else {
            let formatter = DateFormatter(); formatter.dateFormat = "HH:mm:ss"
            for (i, event) in model.events.prefix(2).enumerated() {
                let y = 657 + CGFloat(i)*25
                Bistro.symbol(event.activity.symbol, in: NSRect(x: 30, y: y+2, width: 13, height: 13), color: event.activity.tint)
                Bistro.text(event.client, NSRect(x: 54, y: y, width: 58, height: 20), size: 11, color: Bistro.cream, weight: .medium)
                Bistro.text(event.activity.short + (event.tool.isEmpty ? "" : "  /  \(event.tool)"), NSRect(x: 124, y: y, width: bounds.width-242, height: 20), size: 11, color: Bistro.secondary)
                Bistro.text(formatter.string(from: event.date), NSRect(x: bounds.width-100, y: y, width: 70, height: 20), size: 11, color: Bistro.muted, align: .right)
            }
        }
        Bistro.line(NSPoint(x: 28, y: 716), NSPoint(x: bounds.width-28, y: 716))
        Bistro.iconText("lock", "只展示活动类型，所有内容留在本机", in: NSRect(x: 30, y: 726, width: 320, height: 26), size: 10, color: Bistro.muted, iconSize: 11)
        if !model.demo { Bistro.text("本次上菜 \(model.served) 份", NSRect(x: 370, y: 731, width: 125, height: 20), size: 10, color: Bistro.secondary, align: .right) }
    }
    private func select(_ index: Int) { model.selectedClient = model.clients[index]; refresh() }
    @objc private func clientClick(_ sender: NSButton) { select(sender.tag) }
    @objc private func pinClick() { onPin?() }
    @objc private func foldClick() { onCompact?() }
    @objc private func hideClick() { onHide?() }
    @objc private func liveClick() { model.setDemo(false) }
    @objc private func demoClick() { model.setDemo(true) }
    @objc private func pauseClick() { model.togglePause(); refresh() }
    @objc private func connectClick() { onConnect?() }
    @objc private func orderClick() { onOrder?() }
    @objc private func guideClick() { onGuide?() }
    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
}
