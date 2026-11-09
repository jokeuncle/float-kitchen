import AppKit
import KitchenCore

enum Bistro {
    static let background = color(0x211d19)
    static let surface = color(0x2c2620)
    static let cream = color(0xf9edda)
    static let secondary = color(0xc7b9a6)
    static let muted = color(0xaa9d8b)
    static let copper = color(0xf1ad73)
    static let sage = color(0xb2c8a1)
    static let gold = color(0xe4c174)
    static let error = color(0xf39c89)
    static let rule = color(0x514438)
    static let paper = color(0xf7e8cd)
    static let ink = color(0x413126)
    static let shadow = NSColor.black.withAlphaComponent(0.32)
    static func color(_ hex: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 255)/255, green: CGFloat((hex >> 8) & 255)/255, blue: CGFloat(hex & 255)/255, alpha: 1)
    }
    static func font(_ size: CGFloat, _ weight: NSFont.Weight = .regular, serif: Bool = false) -> NSFont {
        if serif { return NSFont(descriptor: NSFont.systemFont(ofSize: size, weight: weight).fontDescriptor.withDesign(.serif)!, size: size) ?? .systemFont(ofSize: size, weight: weight) }
        return .systemFont(ofSize: size, weight: weight)
    }
    static func text(_ value: String, _ rect: NSRect, size: CGFloat = 12, color: NSColor = cream, weight: NSFont.Weight = .regular, serif: Bool = false, align: NSTextAlignment = .left) {
        NSGraphicsContext.saveGraphicsState(); NSBezierPath(rect: rect).addClip()
        defer { NSGraphicsContext.restoreGraphicsState() }
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = align; paragraph.lineBreakMode = .byTruncatingTail
        (value as NSString).draw(in: rect, withAttributes: [.font: font(size, weight, serif: serif), .foregroundColor: color, .paragraphStyle: paragraph])
    }
    static func round(_ rect: NSRect, radius: CGFloat, color: NSColor) {
        color.setFill(); NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
    }
    static func fitted(_ value: String, width: CGFloat, font: NSFont) -> String {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        if (value as NSString).size(withAttributes: attributes).width <= width { return value }
        let characters = Array(value)
        var low = 0, high = characters.count
        while low < high {
            let middle = (low+high+1)/2
            let candidate = String(characters.prefix(middle)) + "…"
            if (candidate as NSString).size(withAttributes: attributes).width <= width { low = middle } else { high = middle-1 }
        }
        return String(characters.prefix(low)) + "…"
    }
    static func iconText(_ symbol: String, _ value: String, in rect: NSRect, size: CGFloat, color: NSColor, iconColor: NSColor? = nil, weight: NSFont.Weight = .regular, serif: Bool = false, centered: Bool = false, iconSize: CGFloat? = nil) {
        let face = font(size, weight, serif: serif)
        let height = iconSize ?? size+1
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(.init(pointSize: height, weight: .regular))
        image?.isTemplate = false
        image?.lockFocus(); (iconColor ?? color).set(); NSRect(origin: .zero, size: image?.size ?? .zero).fill(using: .sourceAtop); image?.unlockFocus()
        let attachment = NSTextAttachment(); attachment.image = image
        // Center SF Symbol optically on the font's cap-height, on one baseline.
        attachment.bounds = NSRect(x: 0, y: (face.capHeight-height)/2, width: height, height: height)
        let label = NSMutableAttributedString(attachment: attachment)
        label.append(NSAttributedString(string: "  " + value))
        let paragraph = NSMutableParagraphStyle(); paragraph.lineBreakMode = .byTruncatingTail
        label.addAttributes([.font: face, .foregroundColor: color, .paragraphStyle: paragraph], range: NSRange(location: 0, length: label.length))
        let measured = label.size()
        let x = centered ? rect.midX-min(measured.width, rect.width)/2 : rect.minX
        NSGraphicsContext.saveGraphicsState(); NSBezierPath(rect: rect).addClip()
        label.draw(in: NSRect(x: x, y: rect.midY-measured.height/2, width: min(measured.width+1, rect.width), height: measured.height))
        NSGraphicsContext.restoreGraphicsState()
    }
    static func line(_ from: NSPoint, _ to: NSPoint, color: NSColor = rule, width: CGFloat = 0.7) {
        color.setStroke(); let p = NSBezierPath(); p.move(to: from); p.line(to: to); p.lineWidth = width; p.stroke()
    }
    static func symbol(_ name: String, in rect: NSRect, color: NSColor) {
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return }
        image.isTemplate = false
        image.lockFocus(); color.set(); NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop); image.unlockFocus()
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }
}

extension KitchenActivity {
    var atlasIndex: Int {
        switch self { case .reading: return 0; case .searching: return 1; case .cooking: return 2; case .testing: return 3; case .waiting: return 4; case .failed: return 5; case .served: return 6; case .idle: return 7 }
    }
    var meaning: String {
        switch self {
        case .reading: return "读取文件"
        case .searching: return "搜索资料"
        case .cooking: return "执行与修改"
        case .testing: return "运行检查"
        case .waiting: return "等待确认"
        case .failed: return "操作失败"
        case .served: return "本轮完成"
        case .idle: return "暂无活动"
        }
    }
    var motionDescription: String {
        switch self {
        case .reading: return "捧起食谱阅读，厨师专注地轻轻摆动。"
        case .searching: return "提着食材袋，走回自己的工位。"
        case .cooking: return "举起炒锅翻炒，身体与锅一起发力。"
        case .testing: return "掀开锅盖观察火候，锅具轻轻颤动。"
        case .waiting: return "厨师指向服务铃，轻轻摇动并亮起提示光圈。"
        case .failed: return "端起糊锅，所在工位冒出一小团黑烟。"
        case .served: return "双手端出餐盘，把成品送到柜台前。"
        case .idle: return "放下工作，端着咖啡安静休息。"
        }
    }
    var evidenceDescription: String {
        switch self {
        case .reading: return "识别 Read、read_file、list、graph 等工具；部分终端读取命令也可识别。"
        case .searching: return "识别 search、web、browse 等检索工具。"
        case .cooking: return "识别执行、编辑和其他通用工具调用；不代表知道每一条内部操作。"
        case .testing: return "识别常见语言测试命令和专用 test 工具；完整清单见随附说明书。"
        case .waiting: return "仅在来源显式提供 approval / request_user_input / waiting 事件时出现。"
        case .failed: return "仅依据显式工具错误、已识别的非零退出码或 failed 事件；不会凭沉默猜失败。"
        case .served: return "依据 Codex 任务完成、Claude end_turn 或 served 事件；表示本轮结束，未验证任务质量。"
        case .idle: return "启动尚无事件，或来源连续两分钟没有新活动时显示；不表示任务必然结束。"
        }
    }
    var caption: String {
        switch self {
        case .idle: return "歇一会儿，等下一道灵感"
        case .reading: return "翻翻食谱，找一点好食材"
        case .searching: return "出门采购灵感中"
        case .cooking: return "灵感下锅，好戏正在发生"
        case .testing: return "小火慢炖，揭晓之前再检查"
        case .waiting: return "准备好了，等主厨点头"
        case .failed: return "有点糊了，再试一锅"
        case .served: return "叮！这一份灵感，出锅了"
        }
    }
    var short: String {
        switch self {
        case .idle: return "歇业小憩"
        case .reading: return "寻找食材"
        case .searching: return "采购灵感"
        case .cooking: return "正在烹饪"
        case .testing: return "试试火候"
        case .waiting: return "等你点头"
        case .failed: return "重新起锅"
        case .served: return "美味上桌"
        }
    }
    var symbol: String {
        switch self {
        case .idle: return "moon.zzz"
        case .reading: return "book"
        case .searching: return "basket"
        case .cooking: return "flame"
        case .testing: return "timer"
        case .waiting: return "bell"
        case .failed: return "cloud"
        case .served: return "checkmark.seal"
        }
    }
    var tint: NSColor {
        switch self { case .failed: return Bistro.error; case .waiting, .testing: return Bistro.gold; case .served, .reading: return Bistro.sage; default: return Bistro.copper }
    }
}
