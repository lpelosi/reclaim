import Foundation

public enum Tier: Int, Codable, CaseIterable, Comparable {
    case safe = 1
    case review = 2
    case heuristic = 3
    case dangerous = 4

    public var label: String {
        switch self {
        case .safe: return "Safe to delete"
        case .review: return "Review first"
        case .heuristic: return "Heuristic flag"
        case .dangerous: return "Dangerous — confirm"
        }
    }

    public static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct ReportItem: Codable, Identifiable, Hashable {
    public var id: UUID
    public var path: String
    public var size: Int64
    public var tier: Tier
    public var category: String
    public var description: String
    public var lastModified: Date?
    public var ruleId: String
    /// Items sharing a groupId belong to the same duplicate group.
    public var groupId: UUID?
    /// For duplicate items: path of the canonical "keeper" file (usually oldest).
    public var keeperPath: String?
    /// Marks this item as the keeper of its group (do not delete).
    public var isKeeper: Bool

    public init(id: UUID = UUID(), path: String, size: Int64, tier: Tier,
                category: String, description: String, lastModified: Date? = nil,
                ruleId: String, groupId: UUID? = nil, keeperPath: String? = nil,
                isKeeper: Bool = false) {
        self.id = id
        self.path = path
        self.size = size
        self.tier = tier
        self.category = category
        self.description = description
        self.lastModified = lastModified
        self.ruleId = ruleId
        self.groupId = groupId
        self.keeperPath = keeperPath
        self.isKeeper = isKeeper
    }
}

public struct Report: Codable {
    public var generated: Date
    public var totalReclaimable: Int64
    public var items: [ReportItem]

    public init(generated: Date, items: [ReportItem]) {
        self.generated = generated
        self.items = items
        self.totalReclaimable = items.reduce(0) { $0 + $1.size }
    }

    public static func load(from url: URL = Paths.reportURL) -> Report? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try? dec.decode(Report.self, from: data)
    }

    public func save(to url: URL = Paths.reportURL) throws {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(self).write(to: url, options: .atomic)
    }
}

public extension Int64 {
    var humanSize: String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useGB, .useMB, .useKB, .useBytes]
        f.countStyle = .file
        return f.string(fromByteCount: self)
    }
}
