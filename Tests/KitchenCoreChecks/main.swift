import Foundation
import KitchenCore

var checks = 0
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !condition() { fputs("FAIL: \(message)\n", stderr); exit(1) }
}
func parse(_ text: String, client: String = "Codex") -> KitchenEvent? {
    EventParser.parse(Data(text.utf8), client: client, fallbackDate: Date(timeIntervalSince1970: 100))
}
// Breaks caught: missing tool dispatch, accidental interpretation of reasoning,
// malformed payload crashes, replayed completions and false freshness.
expect(parse(#"{"type":"response_item","timestamp":"2026-11-09T08:00:00Z","payload":{"type":"function_call","name":"read_file","call_id":"r1","arguments":"secret"}}"#)?.activity == .reading, "read_file must send the chef to the pantry")
expect(parse(#"{"type":"response_item","payload":{"type":"custom_tool_call","name":"exec","call_id":"e1"}}"#)?.activity == .cooking, "custom exec is cooking")
expect(parse(#"{"type":"response_item","payload":{"type":"function_call","name":"web_search","call_id":"s1"}}"#)?.activity == .searching, "search is ingredient shopping")
expect(parse(#"{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{\"cmd\":\"swift test\"}","call_id":"t1"}}"#)?.activity == .testing, "test commands must animate the pot")
expect(parse(#"{"type":"event_msg","payload":{"type":"task_complete"}}"#)?.activity == .served, "completion serves a dish")
expect(parse(#"{"type":"response_item","payload":{"type":"reasoning","summary":["private"]}}"#) == nil, "reasoning must never enter the kitchen")
expect(parse(#"{"type":"event_msg","payload":{"type":"token_count"}}"#) == nil, "token bookkeeping must not masquerade as activity")
expect(parse("not-json") == nil, "malformed rows are ignored")
expect(parse(#"{"type":"assistant","uuid":"a1","message":{"content":[{"type":"tool_use","name":"Read","id":"u1","input":{"file_path":"private"}}]}}"#, client: "Claude")?.activity == .reading, "Claude Read events work")
expect(parse(#"{"type":"user","message":{"content":[{"type":"tool_result","is_error":true,"tool_use_id":"u1"}]}}"#, client: "Claude")?.activity == .failed, "Claude tool errors cause smoke")
expect(parse(#"{"type":"assistant","message":{"stop_reason":"end_turn","content":[{"type":"text","text":"private"}]}}"#, client: "Claude")?.activity == .served, "Claude final response serves")
expect(parse(#"{"event":"waiting","client":"Claude","id":"hook1"}"#, client: "Local")?.activity == .waiting, "local confirmation events ring the bell")
expect(parse(#"{"event":"waiting","client":"Claude","id":"hook1"}"#, client: "Local")?.client == "Claude", "bridge client labels survive")
expect(parse(#"{"event":"invented"}"#, client: "Local") == nil, "unknown bridge events are ignored")
let dated = parse(#"{"type":"event_msg","timestamp":"2026-11-09T08:00:00.123Z","payload":{"type":"task_complete"}}"#)!
expect(abs(dated.date.timeIntervalSince1970 - 1794211200.123) < 0.01, "source timestamps with fractions are preserved")
let dated2 = parse(#"{"type":"event_msg","timestamp":"2026-11-09T08:00:00Z","payload":{"type":"task_complete"}}"#)!
expect(abs(dated2.date.timeIntervalSince1970 - 1794211200) < 0.01, "source timestamps without fractions are preserved")
let fileInfo = parse(#"{"type":"response_item","payload":{"type":"function_call","name":"read_file","arguments":"{\"path\":\"/private/project/App.swift\"}"}}"#)
expect(fileInfo?.detail == "App.swift", "file activity exposes only a basename")
let commandInfo = parse(#"{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"API_KEY=secret swift test --token secret"}}]}}"#, client: "Claude")
expect(commandInfo?.detail.contains("secret") == false, "command summaries never retain arguments or environment secrets")
expect(parse(#"{"event":"cooking","label":"构建小厨房"}"#, client: "Local")?.detail == "构建小厨房", "custom clients can supply their own task labels")
expect(parse(#"{"type":"response_item","payload":{"type":"function_call","name":"mcp__runner__run_tests"}}"#)?.activity == .testing, "named MCP test tools are recognized without substring matches")
// Test runners are checked through the real event parser, not a mirrored classifier.
let testCommands = [
    "node --test test/*.mjs", "npm test", "npm run test:unit", "pnpm exec vitest run", "npx --yes jest --runInBand", "yarn test", "bun test", "deno test", "npx playwright test", "npx cypress run",
    "pytest -q", "uv run pytest", "poetry run pytest", "python3 -m unittest discover", "coverage run -m pytest", "tox -e py312",
    "go test ./...", "cargo test --workspace", "cargo nextest run", "swift test", "swift run KitchenCoreChecks", "xcodebuild test -scheme Demo",
    "mvn -q test", "./mvnw verify", "./gradlew test", "gradle connectedAndroidTest", "java -jar junit-platform-console-standalone.jar execute",
    "dotnet test", "dotnet vstest app.Tests.dll", "ctest --output-on-failure", "./build/unit_tests --gtest_filter=*", "make test", "cmake --build build --target test", "meson test -C build", "ninja test",
    "bundle exec rspec", "rake test", "ruby -Itest test/app_test.rb", "vendor/bin/phpunit", "php artisan test", "./vendor/bin/pest",
    "mix test", "dart test", "flutter test", "prove -lr t", #"Rscript -e 'testthat::test_dir("tests")'"#, "julia --project -e 'using Pkg; Pkg.test()'", "sbt test", "lein test", "clojure -M:test", "bazel test //...",
    "cd web && npm test", "env CI=1 pnpm test", "bash -lc 'python -m pytest -q'", "npm run build && npm run test:desktop"
]
for command in testCommands {
    let args = String(data: try! JSONSerialization.data(withJSONObject: ["cmd": command]), encoding: .utf8)!
    let row = try! JSONSerialization.data(withJSONObject: ["type": "response_item", "payload": ["type": "function_call", "name": "exec_command", "arguments": args]])
    expect(EventParser.parse(row, client: "Codex")?.activity == .testing, "test runner must be recognized: \(command)")
}
for command in ["go run main.go test", "echo npm test", "printf 'pytest -q'", "cat latest_test_notes.md", "git diff tests", "npm install jest", "pip install pytest", "cargo build --tests", "python script.py", "echo 'mvn test' && git status"] {
    let args = String(data: try! JSONSerialization.data(withJSONObject: ["cmd": command]), encoding: .utf8)!
    let row = try! JSONSerialization.data(withJSONObject: ["type": "response_item", "payload": ["type": "function_call", "name": "exec_command", "arguments": args]])
    expect(EventParser.parse(row, client: "Codex")?.activity != .testing, "ordinary text and installation are not test execution: \(command)")
}
let wrapped = try! JSONSerialization.data(withJSONObject: ["type": "response_item", "payload": ["type": "custom_tool_call", "name": "exec", "input": #"text(await tools.exec_command({cmd: "cargo nextest run", workdir: "/project"}));"#]])
expect(EventParser.parse(wrapped, client: "Codex")?.activity == .testing, "client orchestration wrappers preserve nested command classification")
let commented = try! JSONSerialization.data(withJSONObject: ["type": "response_item", "payload": ["type": "custom_tool_call", "name": "exec", "input": #"// await tools.exec_command({cmd: "pytest"})"#]])
expect(EventParser.parse(commented, client: "Codex")?.activity != .testing, "commented examples in wrapper scripts are not executed tests")
let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }
let file = directory.appendingPathComponent("events.jsonl")
try Data("{\"event\":\"reading\",\"id\":\"one\"}\n".utf8).write(to: file)
let tail = JSONLTailer()
expect(tail.poll(file, client: "Local").map(\.activity) == [.reading], "tailer reads an existing complete row")
expect(tail.poll(file, client: "Local").isEmpty, "unchanged file must never replay events")
let handle = try FileHandle(forWritingTo: file)
try handle.seekToEnd()
try handle.write(contentsOf: Data("{\"event\":\"testing\"".utf8))
expect(tail.poll(file, client: "Local").isEmpty, "partial lines wait for the next write")
try handle.write(contentsOf: Data("}\n".utf8)); try handle.close()
expect(tail.poll(file, client: "Local").map(\.activity) == [.testing], "a split JSON row is reconstructed")
try Data("{\"event\":\"served\"}\n".utf8).write(to: file)
expect(tail.poll(file, client: "Local").map(\.activity) == [.served], "truncation resets the cursor")
expect(tail.poll(directory.appendingPathComponent("missing"), client: "Local").isEmpty, "missing sources remain harmless")
let searchArgs = String(data: try JSONSerialization.data(withJSONObject: ["cmd":"rg -n 'def add' ."]), encoding:.utf8)!
let searchRow = try JSONSerialization.data(withJSONObject:["type":"response_item","payload":["type":"function_call","name":"exec_command","arguments":searchArgs]])
expect(EventParser.parse(searchRow,client:"Codex")?.activity == .searching,"actual local code-search commands are ingredient shopping")

let nestedSearch = try JSONSerialization.data(withJSONObject:["type":"response_item","payload":["type":"custom_tool_call","name":"exec","input":#"text(await tools.exec_command({cmd:"rg -n add .; sleep 4"}));"#]])
expect(EventParser.parse(nestedSearch,client:"Codex")?.activity == .searching,"real Codex exec wrapper exposes local search intent")
let failureText = String(data: try JSONSerialization.data(withJSONObject:["exit_code":1,"output":"fixture failure"]),encoding:.utf8)!
let nestedFailure = try JSONSerialization.data(withJSONObject:["type":"response_item","payload":["type":"custom_tool_call_output","output":[["type":"input_text","text":failureText]]]])
expect(EventParser.parse(nestedFailure,client:"Codex")?.activity == .failed,"real Codex nested command result preserves a nonzero exit code")
let successText = String(data: try JSONSerialization.data(withJSONObject:["exit_code":0,"output":"example says failed but execution succeeded"]),encoding:.utf8)!
let nestedSuccess = try JSONSerialization.data(withJSONObject:["type":"response_item","payload":["type":"custom_tool_call_output","output":[["type":"input_text","text":successText]]]])
expect(EventParser.parse(nestedSuccess,client:"Codex") == nil,"output wording alone must not invent a tool failure")
print("PASS: \(checks) kitchen parser and file-tail checks")
