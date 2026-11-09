import AppKit
import QuartzCore
import Darwin

/// Opt-in diagnostic only. Display callback cadence is reported separately from
/// rendering: it measures main-thread scheduling, not GPU presentation latency.
@available(macOS 14.0, *)
final class FrameProbe: NSObject {
    private var link: CADisplayLink?
    private var times: [Double] = []
    private var startUsage = rusage()
    private var began = 0.0
    private var path = ""
    func start(view: NSView, path: String) {
        self.path = path
        getrusage(RUSAGE_SELF, &startUsage); began = CACurrentMediaTime()
        link = view.displayLink(target: self, selector: #selector(frame(_:)))
        link?.add(to: .main, forMode: .common)
        DispatchQueue.main.asyncAfter(deadline: .now()+8) { [weak self] in self?.finish() }
    }
    @objc private func frame(_ sender: CADisplayLink) { times.append(CACurrentMediaTime()) }
    private func finish() {
        link?.invalidate(); link = nil
        var usage = rusage(); getrusage(RUSAGE_SELF, &usage)
        func cpu(_ value: rusage) -> Double {
            Double(value.ru_utime.tv_sec + value.ru_stime.tv_sec) + Double(value.ru_utime.tv_usec + value.ru_stime.tv_usec)/1_000_000
        }
        let elapsed = CACurrentMediaTime()-began
        let intervals = zip(times.dropFirst(), times).map { ($0-$1)*1000 }.sorted()
        let p95 = intervals.isEmpty ? 0 : intervals[min(intervals.count-1, Int(Double(intervals.count)*0.95))]
        let result: [String: Any] = [
            "duration_seconds": elapsed,
            "process_cpu_percent_one_core": (cpu(usage)-cpu(startUsage))/elapsed*100,
            "peak_resident_mib": Double(usage.ru_maxrss)/1_048_576,
            "display_callbacks": times.count,
            "display_callback_hz": Double(times.count)/elapsed,
            "display_callback_p95_interval_ms": p95,
            "display_callback_worst_interval_ms": intervals.last ?? 0,
            "note": "Display callbacks measure main-thread cadence, not GPU presentation. Animation uses Core Animation with cached image layers."
        ]
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: URL(fileURLWithPath: path)) }
        print("Performance report: \(path)")
    }
}
