import Foundation

/// Recognition only: no command is executed and no arguments are retained.
/// Shell-aware tokenization avoids classifying quoted documentation as a run.
public enum TestCommandClassifier {
    public static func matches(_ command: String) -> Bool { classify(command, depth: 0) }
    public static func matchesOrchestration(_ script: String) -> Bool { embeddedCommands(in: script).contains(where: matches) }
    public static func embeddedCommands(in script: String) -> [String] {
        let pattern = #"(?:tools|functions)\.(?:exec_command|run|shell)\s*\(\s*\{[\s\S]{0,1024}?\b(?:cmd|command)\s*:\s*(\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*')"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        var commands: [String] = []
        let source = script as NSString
        for match in expression.matches(in: script, range: NSRange(location: 0, length: source.length)) {
            let prefix = source.substring(to: match.range.location).components(separatedBy: .newlines).last ?? ""
            if prefix.trimmingCharacters(in: .whitespaces).hasPrefix("//") { continue }
            let literal = source.substring(with: match.range(at: 1))
            let command: String
            if literal.hasPrefix("\"") {
                command = ((try? JSONSerialization.jsonObject(with: Data(("["+literal+"]").utf8))) as? [String])?.first ?? ""
            } else {
                command = String(literal.dropFirst().dropLast()).replacingOccurrences(of: "\\'", with: "'").replacingOccurrences(of: "\\n", with: "\n")
            }
            if !command.isEmpty { commands.append(command) }
        }
        return commands
    }
    private static func classify(_ command: String, depth: Int) -> Bool {
        guard depth < 4 else { return false }
        return segments(command).contains { tokens in
            var words = tokens
            while let first = words.first, first.contains("="), !first.hasPrefix("-") { words.removeFirst() }
            guard let executable = words.first else { return false }
            let name = URL(fileURLWithPath: executable).lastPathComponent.lowercased().replacingOccurrences(of: ".exe", with: "")
            let args = Array(words.dropFirst())
            let lower = args.map { $0.lowercased() }
            if ["echo", "printf", "cat", "rg", "grep", "git", "sed", "head", "tail"].contains(name) { return false }
            if ["bash", "sh", "zsh", "fish", "pwsh", "powershell", "cmd"].contains(name) {
                if let index = lower.firstIndex(where: { $0 == "-command" || $0 == "/c" || ($0.hasPrefix("-") && $0.contains("c")) }), args.indices.contains(index+1) { return classify(args[index+1], depth: depth+1) }
                return false
            }
            if ["env", "time", "command", "exec", "sudo", "timeout"].contains(name) {
                var rest = args
                while let word = rest.first, word.hasPrefix("-") || word.contains("=") || Double(word) != nil { rest.removeFirst() }
                return classify(rest.map(shellQuote).joined(separator: " "), depth: depth+1)
            }
            if ["npx", "bunx"].contains(name) {
                return classify(args.drop(while: { $0.hasPrefix("-") }).map(shellQuote).joined(separator: " "), depth: depth+1)
            }
            if ["uv", "poetry", "pipenv", "bundle", "coverage"].contains(name), let index = lower.firstIndex(of: "run") ?? lower.firstIndex(of: "exec") {
                if name == "coverage", lower.contains("-m"), lower.contains(where: { ["pytest", "unittest", "nose2"].contains($0) }) { return true }
                return classify(args.dropFirst(index+1).map(shellQuote).joined(separator: " "), depth: depth+1)
            }
            if ["npm", "pnpm", "yarn", "bun"].contains(name) {
                guard let action = lower.first(where: { !$0.hasPrefix("-") }) else { return false }
                if action == "test" || action == "t" || action.hasPrefix("test:") { return true }
                if ["run", "run-script"].contains(action), let i = lower.firstIndex(of: action), lower.indices.contains(i+1) {
                    return lower[i+1] == "test" || lower[i+1].hasPrefix("test:") || lower[i+1] == "tests"
                }
                if ["exec", "dlx"].contains(action), let i = lower.firstIndex(of: action) { return classify(args.dropFirst(i+1).map(shellQuote).joined(separator: " "), depth: depth+1) }
                if name == "yarn" { return runner(name: action, args: Array(args.dropFirst())) }
                return false
            }
            if name == "node" { return lower.contains { $0 == "--test" || $0.hasPrefix("--test=") } }
            if name == "python" || name == "python3" || name.hasPrefix("python3.") {
                return zip(lower, lower.dropFirst()).contains { $0 == "-m" && ["pytest", "unittest", "nose", "nose2"].contains($1) }
            }
            if ["go", "swift", "cargo", "dotnet", "mix", "dart", "flutter", "deno", "sbt", "lein", "bazel"].contains(name) {
                if name == "cargo", lower.contains("nextest"), lower.contains("run") { return true }
                if name == "swift", lower.first == "run", args.dropFirst().contains(where: { $0.hasSuffix("Checks") }) { return true }
                if let first = lower.first, ["run", "build", "install", "add", "publish"].contains(first) { return false }
                if lower.contains("test") || (name == "dotnet" && lower.contains("vstest")) { return true }
                return false
            }
            if ["mvn", "mvnw"].contains(name) { return lower.contains { ["test", "verify", "integration-test"].contains($0) } }
            if ["gradle", "gradlew"].contains(name) { return lower.contains { $0 == "test" || $0 == "check" || $0.hasSuffix("test") || $0.hasPrefix("testdebug") || $0.hasPrefix("testrelease") } }
            if name == "xcodebuild" { return lower.contains { $0 == "test" || $0 == "test-without-building" } }
            if ["make", "gmake", "ninja", "meson"].contains(name) { return lower.contains { ["test", "check", "tests"].contains($0) } }
            if name == "cmake" { return lower.contains("--target") && lower.contains { ["test", "check"].contains($0) } }
            if name == "java" { return lower.contains { $0.contains("junit") || $0.contains("testng") } }
            if name == "php" { return lower.contains { $0.hasSuffix("phpunit") || $0.hasSuffix("pest") } || (lower.first == "artisan" && lower.contains("test")) }
            if name == "rake" { return lower.contains { $0 == "test" || $0 == "spec" || $0.hasPrefix("test:") } }
            if name == "ruby" { return lower.contains { $0.hasSuffix("_test.rb") || $0.hasSuffix("_spec.rb") } }
            if name == "rscript" { return lower.contains { $0.contains("testthat::test_") || $0.contains("tinytest::") } }
            if name == "julia" { return lower.contains { $0.contains("pkg.test(") } }
            if name == "clojure" || name == "clj" { return lower.contains { $0.contains(":test") || $0.contains(":kaocha") } }
            if lower.contains(where: { $0.hasPrefix("--gtest_") }) { return true }
            return runner(name: name, args: args)
        }
    }
    private static func runner(name: String, args: [String]) -> Bool {
        let direct: Set<String> = ["pytest", "py.test", "pytest3", "jest", "vitest", "mocha", "ava", "tap", "jasmine", "karma", "phpunit", "pest", "rspec", "ctest", "prove", "nose2", "nosetests", "cucumber", "robot", "runtests", "gotestsum"]
        if direct.contains(name) { return true }
        if name == "playwright" { return args.contains("test") }
        if name == "cypress" { return args.contains("run") || args.contains("open") }
        if name == "tox" || name == "nox" { return !args.contains(where: { ["lint", "format", "docs"].contains($0) }) }
        return false
    }
    private static func shellQuote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }
    private static func segments(_ command: String) -> [[String]] {
        var result: [[String]] = [], words: [String] = [], word = ""
        var quote: Character?, escaped = false
        func flushWord() { if !word.isEmpty { words.append(word); word = "" } }
        func flushSegment() { flushWord(); if !words.isEmpty { result.append(words); words = [] } }
        for character in command {
            if escaped { word.append(character); escaped = false; continue }
            if character == "\\", quote != "'" { escaped = true; continue }
            if let active = quote {
                if character == active { quote = nil } else { word.append(character) }
                continue
            }
            if character == "'" || character == "\"" { quote = character; continue }
            if ";&|\n".contains(character) { flushSegment() }
            else if character.isWhitespace { flushWord() }
            else { word.append(character) }
        }
        flushSegment(); return result
    }
}
