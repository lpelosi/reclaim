import Foundation

public struct ScanProgress: Codable, Equatable {
    public var phase: String
    public var current: Int
    public var total: Int
    public var label: String
    public var startedAt: Date

    public init(phase: String, current: Int, total: Int, label: String, startedAt: Date = Date()) {
        self.phase = phase
        self.current = current
        self.total = total
        self.label = label
        self.startedAt = startedAt
    }

    public var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1.0, max(0.0, Double(current) / Double(total)))
    }

    public static func load(from url: URL = Paths.progressURL) -> ScanProgress? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try? dec.decode(ScanProgress.self, from: data)
    }
}

public final class ProgressReporter {
    private let url: URL
    private let startedAt: Date
    private let throttleInterval: TimeInterval
    private var lastWrite: Date = .distantPast

    public init(url: URL = Paths.progressURL, throttleInterval: TimeInterval = 0.25) {
        self.url = url
        self.startedAt = Date()
        self.throttleInterval = throttleInterval
    }

    public func update(phase: String, current: Int, total: Int, label: String, force: Bool = false) {
        let now = Date()
        if !force && now.timeIntervalSince(lastWrite) < throttleInterval { return }
        lastWrite = now
        let p = ScanProgress(phase: phase, current: current, total: total, label: label, startedAt: startedAt)
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(p) {
            try? data.write(to: url, options: .atomic)
        }
    }

    public func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
