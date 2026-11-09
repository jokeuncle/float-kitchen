import Foundation
import KitchenCore

final class KitchenModel {
    let clients = ["Codex", "Claude", "Local"]
    var selectedClient = "Codex"
    private(set) var demo = true
    private(set) var paused = false
    private(set) var events: [KitchenEvent] = []
    private(set) var states: [String: KitchenEvent] = [:]
    private(set) var served = 0
    private var seen = Set<String>()
    private var seenOrder: [String] = []
    private var demoStart = Date()
    private var demoStep = -1
    private var pausedAt: Date?
    private var showcasing = false
    func demonstrate(_ activity: KitchenActivity) {
        setDemo(true); paused = false; showcasing = true; states = [:]; events = []
        let examples: [KitchenActivity: String] = [.reading: "App.swift", .searching: "检索资料", .cooking: "swift build", .testing: "swift test", .waiting: "等待你的确认", .failed: "工具报告错误", .served: "收到完成事件", .idle: "等待下一份任务"]
        let event = KitchenEvent(id: UUID().uuidString, client: selectedClient, activity: activity, tool: "演示", detail: examples[activity] ?? "")
        accept(event); onChange?()
    }
    var onChange: (() -> Void)?
    var onModeChange: (() -> Void)?
    var current: KitchenEvent { states[selectedClient] ?? KitchenEvent(id: "idle", client: selectedClient, activity: .idle) }
    var activity: KitchenActivity {
        if !demo && Date().timeIntervalSince(current.date) > 120 { return .idle }
        return current.activity
    }
    func setDemo(_ value: Bool) {
        if demo == value {
            if showcasing { showcasing = false; demoStart = Date(); demoStep = -1; tick() }
            return
        }
        showcasing = false
        demo = value; paused = false; events = []; states = [:]; served = 0
        demoStart = Date(); demoStep = -1; seen.removeAll(); seenOrder.removeAll()
        onModeChange?(); tick(); onChange?()
    }
    func togglePause() {
        paused.toggle()
        if paused { pausedAt = Date() }
        else if let date = pausedAt { demoStart = demoStart.addingTimeInterval(Date().timeIntervalSince(date)); pausedAt = nil }
        onChange?()
    }
    func tick() {
        guard demo, !paused, !showcasing else { return }
        let step = Int(Date().timeIntervalSince(demoStart) / 7)
        guard step != demoStep else { return }
        demoStep = step
        let sequence: [KitchenActivity] = [.reading, .searching, .cooking, .testing, .failed, .cooking, .waiting, .served, .idle]
        for (index, client) in clients.enumerated() {
            let activity = sequence[(step + index * 2) % sequence.count]
            accept(KitchenEvent(id: "demo-\(step)-\(client)", client: client, activity: activity, tool: ["read_file", "web_search", "exec_command", "swift test", "tool_error", "apply_patch", "approval", "task_complete", ""][sequence.firstIndex(of: activity)!]))
        }
        onChange?()
    }
    func accept(_ event: KitchenEvent) {
        guard !seen.contains(event.id), clients.contains(event.client) else { return }
        seen.insert(event.id); seenOrder.append(event.id)
        if seenOrder.count > 1024 { seen.remove(seenOrder.removeFirst()) }
        states[event.client] = event
        events.insert(event, at: 0); if events.count > 6 { events.removeLast() }
        if event.activity == .served { served += 1 }
    }
    func receive(_ incoming: [KitchenEvent]) {
        guard !demo else { return }
        for event in incoming.sorted(by: { $0.date < $1.date }) where abs(event.date.timeIntervalSinceNow) < 120 { accept(event) }
        onChange?()
    }
}

final class KitchenWatcher {
    private let queue = DispatchQueue(label: "FloatKitchen.events", qos: .utility)
    private var tail = JSONLTailer()
    private var timer: DispatchSourceTimer?
    private var sources: [(URL, String)] = []
    private var nextDiscovery = Date.distantPast
    var exactCodexLog: URL?
    private let home = FileManager.default.homeDirectoryForCurrentUser
    let bridge: URL
    var customSource: URL?
    var onEvents: (([KitchenEvent]) -> Void)?
    init() {
        bridge = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/FloatKitchen/events.jsonl")
        try? FileManager.default.createDirectory(at: bridge.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: bridge.path) { FileManager.default.createFile(atPath: bridge.path, contents: Data(), attributes: [.posixPermissions: 0o600]) }
    }
    func start() {
        guard timer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .seconds(2), leeway: .milliseconds(250))
        timer.setEventHandler { [weak self] in self?.poll() }
        self.timer = timer; timer.resume()
    }
    func stop() { timer?.cancel(); timer = nil }
    func reset() { queue.async { [weak self] in self?.tail = JSONLTailer(); self?.nextDiscovery = .distantPast } }
    func watch(_ url: URL) { queue.async { [weak self] in self?.customSource = url; self?.tail = JSONLTailer() } }
    private func poll() {
        // Local bridges should not wait for directory discovery of other clients.
        var local = tail.poll(bridge, client: "Local")
        if let customSource { local += tail.poll(customSource, client: "Local") }
        if !local.isEmpty {
            let result = local
            DispatchQueue.main.async { [weak self] in self?.onEvents?(result) }
        }
        if let exactCodexLog {
            sources = [(exactCodexLog, "Codex")]
        } else if Date() >= nextDiscovery {
            nextDiscovery = Date().addingTimeInterval(20)
            sources = recentFiles(home.appendingPathComponent(".codex/sessions"), client: "Codex")
                + recentFiles(home.appendingPathComponent(".claude/projects"), client: "Claude")
        }
        var events: [KitchenEvent] = []
        for (url, client) in sources { events += tail.poll(url, client: client) }
        let result = events
        DispatchQueue.main.async { [weak self] in self?.onEvents?(result) }
    }
    private func recentFiles(_ directory: URL, client: String) -> [(URL, String)] {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
        guard let entries = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else { return [] }
        let cutoff = Date().addingTimeInterval(-180)
        var candidates: [(URL, Date)] = []
        var visited = 0
        while let url = entries.nextObject() as? URL {
            visited += 1; if visited > 20_000 { break }
            guard url.pathExtension == "jsonl", let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true, let date = values.contentModificationDate, date > cutoff else { continue }
            candidates.append((url, date))
        }
        return candidates.sorted { $0.1 > $1.1 }.prefix(4).map { ($0.0, client) }
    }
    deinit { stop() }
}
