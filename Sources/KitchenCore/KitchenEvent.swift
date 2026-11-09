import Foundation

public enum KitchenActivity: String, Codable, CaseIterable {
    case idle, reading, searching, cooking, testing, waiting, failed, served
}

public struct KitchenEvent: Equatable {
    public let id: String
    public let client: String
    public let activity: KitchenActivity
    public let tool: String
    public let detail: String
    public let date: Date
    public init(id: String, client: String, activity: KitchenActivity, tool: String = "", detail: String = "", date: Date = Date()) {
        self.id = id; self.client = client; self.activity = activity; self.tool = tool; self.detail = detail; self.date = date
    }
}

public enum EventParser {
    public static func parse(_ data: Data, client: String, fallbackDate: Date = Date()) -> KitchenEvent? {
        guard let row = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        let payload = row["payload"] as? [String: Any] ?? [:]
        let timestamp = row["timestamp"] as? String ?? ""
        let date = timestamp.isEmpty ? fallbackDate : (fractional.date(from: timestamp) ?? plain.date(from: timestamp) ?? fallbackDate)
        var hash: UInt64 = 14695981039346656037
        for byte in data { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        let identity = String(hash, radix: 16)
        func event(_ activity: KitchenActivity, _ tool: String = "", _ source: String? = nil, detail: String = "") -> KitchenEvent {
            KitchenEvent(id: identity, client: source ?? client, activity: activity, tool: String(tool.prefix(60)), detail: detail, date: date)
        }
        if let value = row["event"] as? String, let activity = KitchenActivity(rawValue: value) {
            let label = (row["label"] as? String ?? "").components(separatedBy: .newlines).joined(separator: " ")
            return event(activity, row["tool"] as? String ?? "", row["client"] as? String, detail: String(label.prefix(90)))
        }
        if client == "Codex" {
            let type = payload["type"] as? String ?? ""
            if row["type"] as? String == "event_msg" {
                switch type {
                case "task_started", "user_message": return event(.cooking)
                case "task_complete", "task_completed", "turn_complete": return event(.served)
                case "turn_aborted", "error": return event(.failed)
                case "approval_request", "request_user_input": return event(.waiting)
                default: return nil
                }
            }
            if type == "function_call" || type == "custom_tool_call" {
                let name = payload["name"] as? String ?? "tool"
                let args = payload["arguments"] as? String ?? payload["input"] as? String ?? ""
                let input = (try? JSONSerialization.jsonObject(with: Data(args.utf8))) as? [String: Any] ?? [:]
                let command = TestCommandClassifier.embeddedCommands(in: args).first
                let detail = input.isEmpty ? command.map { summary(["command": $0]) } ?? "" : summary(input)
                return event(classify(name: name, arguments: args), name, detail: detail)
            }
            if type == "function_call_output" || type == "custom_tool_call_output" {
                if payload["is_error"] as? Bool == true { return event(.failed) }
                if let output = payload["output"] as? String,
                   let object = (try? JSONSerialization.jsonObject(with: Data(output.utf8))) as? [String: Any],
                   let code = object["exit_code"] as? Int, code != 0 { return event(.failed) }
                if let blocks = payload["output"] as? [[String: Any]] {
                    for block in blocks {
                        guard let text = block["text"] as? String,
                              let result = (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any],
                              let code = result["exit_code"] as? Int, code != 0 else { continue }
                        return event(.failed, "exec_command", detail: "退出码 \(code)")
                    }
                }
            }
        }
        if client == "Claude" {
            let message = row["message"] as? [String: Any] ?? [:]
            let blocks = message["content"] as? [[String: Any]] ?? []
            for block in blocks {
                if block["type"] as? String == "tool_result", block["is_error"] as? Bool == true { return event(.failed) }
                if block["type"] as? String == "tool_use" {
                    let name = block["name"] as? String ?? "tool"
                    let input = block["input"] as? [String: Any] ?? [:]
                    return event(classify(name: name, arguments: input["command"] as? String ?? ""), name, detail: summary(input))
                }
            }
            if message["stop_reason"] as? String == "end_turn" { return event(.served) }
        }
        return nil
    }

    private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()
    private static let plain = ISO8601DateFormatter()

    private static func summary(_ input: [String: Any]) -> String {
        for key in ["file_path", "path", "file"] {
            if let path = input[key] as? String { return String(URL(fileURLWithPath: path).lastPathComponent.prefix(90)) }
        }
        if let command = input["cmd"] as? String ?? input["command"] as? String {
            let words = command.split(whereSeparator: \.isWhitespace).map(String.init)
            let runners = ["swift", "npm", "pnpm", "yarn", "cargo", "python", "python3", "pytest", "node", "go", "git", "xcodebuild", "rg", "cat", "ls", "make"]
            if let runner = words.first(where: runners.contains) {
                if ["python", "python3"].contains(runner), let index = words.firstIndex(of: "-m"), words.indices.contains(index+1), ["pytest", "unittest", "nose2"].contains(words[index+1]) { return "\(runner) -m \(words[index+1])" }
                let operations = ["test", "build", "check", "run", "install", "status", "diff", "typecheck", "lint"]
                let operation = words.first(where: operations.contains)
                return runner + (operation.map { " " + $0 } ?? "")
            }
            return "运行命令"
        }
        return ""
    }

    private static func classify(name: String, arguments: String) -> KitchenActivity {
        let name = name.lowercased()
        if name.contains("request_user") || name.contains("approval") { return .waiting }
        if name == "grep" || name == "rg" || name.hasSuffix("__grep") { return .searching }
        if name.contains("search") || name.contains("browse") || name.contains("web") { return .searching }
        if name.contains("read") || name.contains("list") || name.contains("glob") || name.contains("snippet") || name.contains("graph") || name.contains("view_image") || name.contains("get_app_state") || name.contains("snapshot") || name.contains("architecture") { return .reading }
        let tokens = name.split { !$0.isLetter && !$0.isNumber }
        if !Set(tokens.map(String.init)).isDisjoint(with: ["test", "tests", "pytest", "unittest", "vitest", "jest", "phpunit", "rspec", "ctest", "runtests"]) { return .testing }
        if name.contains("exec") || name == "bash" || name.contains("terminal") {
            let command = arguments.lowercased()
            let object = (try? JSONSerialization.jsonObject(with: Data(arguments.utf8))) as? [String: Any]
            let shell = object?["cmd"] as? String ?? object?["command"] as? String ?? arguments
            if TestCommandClassifier.matches(shell) { return .testing }
            if name == "exec" || name == "functions.exec", TestCommandClassifier.matchesOrchestration(arguments) { return .testing }
            if name == "exec" || name == "functions.exec", let command = TestCommandClassifier.embeddedCommands(in: arguments).first { return classify(name: "exec_command", arguments: command) }
            if shell.trimmingCharacters(in: .whitespacesAndNewlines).range(of: #"^(?:rg|grep|fd|find)\s"#, options: .regularExpression) != nil { return .searching }
            if ["cat ", "rg ", "ls ", "sed -n"].contains(where: command.contains) { return .reading }
        }
        return .cooking
    }
}
