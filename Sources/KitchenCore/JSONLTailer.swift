import Foundation

public final class JSONLTailer {
    private struct Cursor { var offset: UInt64 = 0; var pending = Data(); var inode: UInt64 = 0; var discarding = false }
    private var cursors: [URL: Cursor] = [:]
    private let limit = 524_288
    public init() {}
    public func poll(_ url: URL, client: String) -> [KitchenEvent] {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? UInt64,
              let handle = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? handle.close() }
        let inode = attributes[.systemFileNumber] as? UInt64 ?? 0
        let modified = attributes[.modificationDate] as? Date ?? Date()
        var cursor = cursors[url] ?? Cursor()
        if cursor.inode != inode || size < cursor.offset { cursor = Cursor() }
        cursor.inode = inode
        if size > cursor.offset + UInt64(limit) {
            cursor.offset = size - UInt64(limit); cursor.pending = Data(); cursor.discarding = true
        }
        guard (try? handle.seek(toOffset: cursor.offset)) != nil,
              let data = try? handle.read(upToCount: limit), !data.isEmpty else { return [] }
        cursor.offset += UInt64(data.count)
        cursor.pending.append(data)
        var events: [KitchenEvent] = []
        while let newline = cursor.pending.firstIndex(of: 10) {
            let line = Data(cursor.pending[..<newline])
            cursor.pending.removeSubrange(...newline)
            if cursor.discarding { cursor.discarding = false; continue }
            if let event = EventParser.parse(line, client: client, fallbackDate: modified) { events.append(event) }
        }
        if cursor.pending.count > limit { cursor.pending.removeAll(keepingCapacity: true); cursor.discarding = true }
        cursors[url] = cursor
        // Keep discovery of rotated sessions from accumulating unbounded cursor state.
        if cursors.count > 64 { cursors = [url: cursor] }
        return events
    }
}
