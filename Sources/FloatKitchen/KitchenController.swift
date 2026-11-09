import AppKit
import KitchenCore

final class KitchenPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class KitchenController: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = KitchenModel()
    let watcher = KitchenWatcher()
    var panel: KitchenPanel!
    var view: KitchenView!
    var status: NSStatusItem!
    var timer: Timer?
    var pinned = true
    var compact = false
    var connection: NSWindow?
    var receipt: NSWindow?
    var receiptText: NSTextView?
    var guide: NSWindow?
    var probe: AnyObject?
    private var auditURL: URL?
    private var lastAuditID = ""
    private let defaults = UserDefaults.standard
    func applicationDidFinishLaunching(_ notification: Notification) {
        func option(_ name: String) -> String? {
            guard let i = CommandLine.arguments.firstIndex(of: name), CommandLine.arguments.indices.contains(i+1) else { return nil }
            return CommandLine.arguments[i+1]
        }
        if let path = option("--codex-log") { watcher.exactCodexLog = URL(fileURLWithPath: path) }
        if let path = option("--event-audit") { auditURL = URL(fileURLWithPath: path) }
        makePanel(); makeMenu()
        watcher.onEvents = { [weak self] events in self?.model.receive(events) }
        model.onChange = { [weak self] in self?.view.refresh(); self?.updateReceipt(); self?.auditView() }
        model.onModeChange = { [weak self] in
            guard let self else { return }
            if model.demo { watcher.stop() } else { watcher.reset(); watcher.start() }
        }
        if CommandLine.arguments.contains("--live") { model.setDemo(false) } else { model.tick() }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.model.tick() }
        timer?.tolerance = 0.2
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(sleeping), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(waking), name: NSWorkspace.didWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(accessibility), name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(visibility), name: NSWindow.didChangeOcclusionStateNotification, object: panel)
        panel.orderFrontRegardless(); view.refresh()
        if let i = CommandLine.arguments.firstIndex(of: "--preview-dir"), CommandLine.arguments.indices.contains(i+1) {
            let directory = CommandLine.arguments[i+1]
            DispatchQueue.main.asyncAfter(deadline: .now()+1) { [weak self] in self?.exportPreview(directory) }
        }
        if CommandLine.arguments.contains("--self-check") {
            DispatchQueue.main.asyncAfter(deadline: .now()+1.5) { [weak self] in self?.selfCheck() }
        }
        if CommandLine.arguments.contains("--integration-check") {
            DispatchQueue.main.asyncAfter(deadline: .now()+0.5) { [weak self] in self?.integrationCheck() }
        }
        if let i = CommandLine.arguments.firstIndex(of: "--performance-report"), CommandLine.arguments.indices.contains(i+1) {
            if #available(macOS 14.0, *) {
                let diagnostic = FrameProbe(); probe = diagnostic
                diagnostic.start(view: view, path: CommandLine.arguments[i+1])
            }
        }
    }
    private func makePanel() {
        let size = NSSize(width: 680, height: 764)
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let saved = defaults.string(forKey: "origin").map(NSPointFromString)
        let origin = saved ?? NSPoint(x: screen.maxX-size.width-30, y: screen.midY-size.height/2)
        panel = KitchenPanel(contentRect: NSRect(origin: origin, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Float Kitchen · AI 后厨"; panel.backgroundColor = .clear; panel.isOpaque = false
        panel.hasShadow = true; panel.level = .floating; panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false; panel.isMovableByWindowBackground = true
        panel.becomesKeyOnlyIfNeeded = true; panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.appearance = NSAppearance(named: .darkAqua); panel.delegate = self
        view = KitchenView(frame: NSRect(origin: .zero, size: size), model: model)
        view.autoresizingMask = [.width, .height]
        view.onPin = { [weak self] in self?.togglePin() }
        view.onCompact = { [weak self] in self?.toggleCompact() }
        view.onHide = { [weak self] in self?.panel.orderOut(nil); self?.view.refresh() }
        view.onConnect = { [weak self] in self?.showConnection() }
        view.onOrder = { [weak self] in self?.showReceipt() }
        view.onGuide = { [weak self] in self?.showGuide() }
        panel.contentView = view
        constrain()
    }
    private func makeMenu() {
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.image = NSImage(systemSymbolName: "frying.pan", accessibilityDescription: "Float Kitchen")
        status.button?.toolTip = "Float Kitchen · AI 后厨"
        let menu = NSMenu()
        for (title, selector, key) in [
            ("显示厨房", #selector(show), ""),
            ("切换迷你厨房", #selector(toggleCompact), ""),
            ("切换置顶", #selector(togglePin), ""),
            ("真实活动 / 演示", #selector(toggleMode), ""),
            ("接入事件…", #selector(showConnection), ""),
            ("订单小票…", #selector(showReceipt), ""),
            ("看懂后厨…", #selector(showGuide), ""),
            ("重置位置", #selector(resetPosition), ""),
            ("退出 Float Kitchen", #selector(quit), "q")
        ] { let item = NSMenuItem(title: title, action: selector, keyEquivalent: key); item.target = self; menu.addItem(item) }
        status.menu = menu
    }
    @objc func show() { panel.orderFrontRegardless(); view.refresh() }
    @objc func togglePin() { pinned.toggle(); panel.level = pinned ? .floating : .normal; view.pinned = pinned }
    @objc func toggleMode() { model.setDemo(!model.demo) }
    @objc func toggleCompact() {
        compact.toggle()
        let size = compact ? NSSize(width: 440, height: 400) : NSSize(width: 680, height: 764)
        let old = panel.frame
        view.compact = compact
        panel.setFrame(NSRect(x: old.maxX-size.width, y: old.maxY-size.height, width: size.width, height: size.height), display: true)
        constrain(); view.layoutSubtreeIfNeeded(); view.refresh()
    }
    @objc func resetPosition() {
        guard let screen = NSScreen.main?.visibleFrame else { return }
        panel.setFrameOrigin(NSPoint(x: screen.maxX-panel.frame.width-30, y: screen.midY-panel.frame.height/2)); constrain()
    }
    private func constrain() {
        let screens = NSScreen.screens.map(\.visibleFrame)
        let screen = screens.first { $0.intersects(panel.frame) } ?? NSScreen.main?.visibleFrame ?? panel.frame
        var frame = panel.frame
        frame.origin.x = min(max(frame.minX, screen.minX), screen.maxX-frame.width)
        frame.origin.y = min(max(frame.minY, screen.minY), screen.maxY-frame.height)
        panel.setFrame(frame, display: true)
    }
    func windowDidMove(_ notification: Notification) { defaults.set(NSStringFromPoint(panel.frame.origin), forKey: "origin") }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { show(); return true }
    @objc private func sleeping() { view.sleeping = true; watcher.stop() }
    @objc private func waking() { view.sleeping = false; if !model.demo { watcher.start() } }
    @objc private func visibility() { view.sleeping = !panel.isVisible || !panel.occlusionState.contains(.visible) }
    @objc private func accessibility() { view.refresh() }
    @objc private func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { watcher.stop(); timer?.invalidate() }
    @objc func showConnection() {
        if let connection { connection.makeKeyAndOrderFront(nil); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 510, height: 330), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "连接你的 AI 厨房"; window.isReleasedWhenClosed = false
        window.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        window.appearance = NSAppearance(named: .darkAqua); window.backgroundColor = Bistro.background
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 510, height: 330))
        func label(_ text: String, y: CGFloat, size: CGFloat = 13) {
            let l = NSTextField(wrappingLabelWithString: text); l.font = Bistro.font(size); l.textColor = Bistro.cream
            l.frame = NSRect(x: 28, y: y, width: 454, height: 46); content.addSubview(l)
        }
        label("Codex 和 Claude 会自动连接。", y: 263, size: 22)
        label("切到「真实活动」后，读取最近更新的本地会话日志。只提取工具名、时间和活动类型，不展示对话或推理。", y: 205)
        label("其他客户端可向本地事件文件追加一行 JSON：", y: 157)
        let code = NSTextField(labelWithString: #"{"event":"cooking","client":"Local"}"#)
        code.font = .monospacedSystemFont(ofSize: 12, weight: .regular); code.textColor = Bistro.copper
        code.frame = NSRect(x: 28, y: 130, width: 455, height: 24); content.addSubview(code)
        let folder = NSButton(title: "打开事件目录", target: self, action: #selector(revealBridge)); folder.frame = NSRect(x: 25, y: 76, width: 145, height: 32)
        let file = NSButton(title: "连接其他 JSONL…", target: self, action: #selector(importFile)); file.frame = NSRect(x: 180, y: 76, width: 165, height: 32)
        content.addSubview(folder); content.addSubview(file)
        label("支持 reading / searching / cooking / testing / waiting / failed / served / idle。关闭本窗口不影响连接。", y: 15, size: 11)
        window.contentView = content; window.center(); window.makeKeyAndOrderFront(nil); connection = window
    }
    @objc private func revealBridge() { NSWorkspace.shared.activateFileViewerSelecting([watcher.bridge]) }
    @objc func showGuide() {
        if let guide { guide.makeKeyAndOrderFront(nil); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 640), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "看懂后厨 · 动作说明书"; window.isReleasedWhenClosed = false; window.appearance = NSAppearance(named: .darkAqua)
        window.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 580, height: 640)); scroll.hasVerticalScroller = true
        let content = KitchenGuideView(frame: NSRect(x: 0, y: 0, width: 580, height: 1110))
        content.onDemonstrate = { [weak self] activity in self?.model.demonstrate(activity); self?.guide?.orderOut(nil); self?.show() }
        scroll.documentView = content; window.contentView = scroll; window.center(); window.makeKeyAndOrderFront(nil); guide = window
    }
    @objc func showReceipt() {
        if let receipt { updateReceipt(); receipt.makeKeyAndOrderFront(nil); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 490), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "订单小票"; window.isReleasedWhenClosed = false; window.appearance = NSAppearance(named: .aqua)
        window.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 480, height: 490)); scroll.autoresizingMask = [.width, .height]; scroll.hasVerticalScroller = true
        let text = NSTextView(frame: scroll.bounds); text.isEditable = false; text.isSelectable = true
        text.autoresizingMask = [.width]; text.textContainerInset = NSSize(width: 28, height: 24)
        text.textContainer?.widthTracksTextView = true; text.isVerticallyResizable = true; text.isHorizontallyResizable = false; text.backgroundColor = Bistro.paper
        scroll.documentView = text; window.contentView = scroll; receiptText = text; receipt = window
        updateReceipt(); window.center(); window.makeKeyAndOrderFront(nil)
    }
    private func updateReceipt() {
        guard let text = receiptText else { return }
        let result = NSMutableAttributedString()
        func append(_ string: String, size: CGFloat, weight: NSFont.Weight = .regular, serif: Bool = false) {
            let paragraph = NSMutableParagraphStyle(); paragraph.paragraphSpacing = 12; paragraph.lineSpacing = 4
            result.append(NSAttributedString(string: string + "\n", attributes: [.font: Bistro.font(size, weight, serif: serif), .foregroundColor: Bistro.ink, .paragraphStyle: paragraph]))
        }
        append("Float Kitchen", size: 28, weight: .semibold, serif: true)
        append(model.demo ? "演示小票 · 以下是虚构活动" : "本地活动小票 · 最近六步", size: 13)
        let formatter = DateFormatter(); formatter.dateFormat = "HH:mm:ss"
        if model.events.isEmpty { append("还没有新订单。客户端开始工作后，活动会出现在这里。", size: 14) }
        for event in model.events {
            append("\(formatter.string(from: event.date))   \(event.client)   \(event.activity.short)", size: 14, weight: .semibold)
            if !event.tool.isEmpty || !event.detail.isEmpty { append([event.tool, event.detail].filter { !$0.isEmpty }.joined(separator: "  /  "), size: 12) }
        }
        append("小票仅保留活动类型、工具名、文件名或命令类别。对话、工具输出和私有推理不在此处显示。", size: 11)
        text.textStorage?.setAttributedString(result)
    }
    @objc private func importFile() {
        let dialog = NSOpenPanel(); dialog.canChooseDirectories = false; dialog.allowsMultipleSelection = false; dialog.message = "选择持续追加的 JSONL 活动文件"
        dialog.begin { [weak self] response in
            guard response == .OK, let url = dialog.url, let self else { return }
            self.watcher.watch(url); self.model.setDemo(false); self.connection?.orderOut(nil)
        }
    }
    private func capture(_ url: URL) {
        view.layoutSubtreeIfNeeded(); view.displayIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) { try? data.write(to: url) }
    }
    private func auditView() {
        guard let auditURL, !model.demo, model.current.id != lastAuditID else { return }
        lastAuditID = model.current.id
        let record: [String: Any] = ["observed_at": ISO8601DateFormatter().string(from: Date()), "event_at": ISO8601DateFormatter().string(from: model.current.date), "activity": model.activity.rawValue, "meaning": model.activity.meaning, "caption": model.activity.caption, "tool": model.current.tool, "detail": model.current.detail, "client": model.current.client]
        try? FileManager.default.createDirectory(at: auditURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: auditURL.path) { FileManager.default.createFile(atPath: auditURL.path, contents: nil, attributes: [.posixPermissions: 0o600]) }
        if let handle = try? FileHandle(forWritingTo: auditURL), var data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]) {
            defer { try? handle.close() }; _ = try? handle.seekToEnd(); data.append(10); try? handle.write(contentsOf: data)
        }
        let state = model.activity.rawValue
        DispatchQueue.main.asyncAfter(deadline: .now()+0.5) { [weak self] in
            guard let self, model.activity.rawValue == state else { return }
            self.capture(auditURL.deletingLastPathComponent().appendingPathComponent("state-\(state).png"))
        }
    }
    private func exportPreview(_ path: String) {
        let directory = URL(fileURLWithPath: path); try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        capture(directory.appendingPathComponent("kitchen-expanded.png"))
        toggleCompact(); capture(directory.appendingPathComponent("kitchen-compact.png")); toggleCompact()
        showReceipt()
        if let content = receipt?.contentView, let rep = content.bitmapImageRepForCachingDisplay(in: content.bounds) {
            content.cacheDisplay(in: content.bounds, to: rep)
            if let data = rep.representation(using: .png, properties: [:]) { try? data.write(to: directory.appendingPathComponent("kitchen-receipt.png")) }
        }
        receipt?.orderOut(nil)
        let activities: [KitchenActivity] = [.reading, .searching, .cooking, .testing, .waiting, .failed, .served, .idle]
        for activity in activities {
            model.demonstrate(activity); view.refresh()
            capture(directory.appendingPathComponent("activity-\(activity.rawValue).png"))
        }
        model.demonstrate(.reading)
        model.accept(KitchenEvent(id: UUID().uuidString, client: model.selectedClient, activity: .reading, tool: String(repeating: "very_long_tool_name_", count: 4), detail: String(repeating: "一个很长的文件名称MixedEnglishAnd中文", count: 5)))
        view.refresh(); capture(directory.appendingPathComponent("kitchen-long-text.png"))
        toggleCompact(); capture(directory.appendingPathComponent("kitchen-compact-long-text.png")); toggleCompact()
        showGuide()
        if let content = guide?.contentView, let rep = content.bitmapImageRepForCachingDisplay(in: content.bounds) {
            content.cacheDisplay(in: content.bounds, to: rep)
            if let data = rep.representation(using: .png, properties: [:]) { try? data.write(to: directory.appendingPathComponent("kitchen-guide.png")) }
        }
        guide?.orderOut(nil); model.setDemo(true)
        print("Kitchen previews saved: \(path)")
    }
    private func integrationCheck() {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("kitchen-integration-\(UUID().uuidString).jsonl")
        let row: [String: Any] = ["id": UUID().uuidString, "timestamp": ISO8601DateFormatter().string(from: Date()), "client": "Local", "event": "testing", "tool": "swift test", "label": "端到端验收"]
        do { var data = try JSONSerialization.data(withJSONObject: row); data.append(10); try data.write(to: file) } catch { fputs("Integration fixture write failed: \(error)\n", stderr); exit(1) }
        watcher.watch(file); model.setDemo(false)
        DispatchQueue.main.asyncAfter(deadline: .now()+4) { [weak self] in
            guard let self else { return }
            let event = model.states["Local"]
            let passed = event?.activity == .testing && event?.detail == "端到端验收"
            let report: [String: Any] = ["event_traveled_file_to_background_watcher_to_model": passed, "client": event?.client ?? "missing", "activity": event?.activity.rawValue ?? "missing", "detail": event?.detail ?? "missing"]
            let destination = CommandLine.arguments.firstIndex(of: "--integration-report").flatMap { CommandLine.arguments.indices.contains($0+1) ? CommandLine.arguments[$0+1] : nil } ?? "/tmp/float-kitchen-integration.json"
            if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: URL(fileURLWithPath: destination)) }
            try? FileManager.default.removeItem(at: file)
            if !passed { exit(1) }
            self.model.setDemo(true)
            if CommandLine.arguments.contains("--exit-after-check") { NSApp.terminate(nil) }
        }
    }
    private func selfCheck() {
        var results: [String: Bool] = [:]
        results["native_floating_panel"] = panel.level == .floating && panel.isFloatingPanel
        results["art_assets_loaded"] = KitchenStage.load("kitchen") != nil && KitchenStage.load("chef-states") != nil
        results["demo_is_labeled"] = model.demo && !model.events.isEmpty
        toggleCompact(); results["compact_geometry"] = panel.frame.size == NSSize(width: 440, height: 400)
        toggleCompact(); results["expanded_geometry"] = panel.frame.size == NSSize(width: 680, height: 764)
        togglePin(); results["unpin"] = panel.level == .normal; togglePin()
        model.setDemo(false); results["live_has_no_demo_events"] = model.events.isEmpty
        model.setDemo(true)
        panel.orderOut(nil); view.refresh(); results["hidden_animation_stopped"] = !panel.isVisible
        show(); results["menu_recovers_window"] = panel.isVisible
        results["bridge_exists"] = FileManager.default.fileExists(atPath: watcher.bridge.path)
        results["controls_stay_inside_window"] = view.subviews.filter { !$0.isHidden && $0 is NSButton }.allSatisfy { view.bounds.contains($0.frame) }
        let path = ProcessInfo.processInfo.environment["KITCHEN_CHECK_PATH"] ?? "/tmp/float-kitchen-checks.json"
        if let data = try? JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: URL(fileURLWithPath: path)) }
        print(results)
        if results.values.contains(false) { exit(1) }
        if CommandLine.arguments.contains("--exit-after-check") { NSApp.terminate(nil) }
    }
}
