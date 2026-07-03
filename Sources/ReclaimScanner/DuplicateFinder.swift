import Foundation
import CryptoKit
import ReclaimCore

public final class DuplicateFinder {
    let roots: [String]
    let minBytes: Int64
    let pruneNames: Set<String>
    let whitelist: Whitelist

    public init(
        roots: [String] = ["~/Downloads", "~/Desktop", "~/Documents"],
        minBytes: Int64 = 10_000_000, // 10 MB
        pruneNames: Set<String> = [
            "Library", ".git", "node_modules", ".build", ".swiftpm",
            "DerivedData", "target", ".venv", "venv", "__pycache__",
            ".next", ".nuxt", ".gradle", "Pods"
        ],
        whitelist: Whitelist
    ) {
        self.roots = roots.map(Paths.expand)
        self.minBytes = minBytes
        self.pruneNames = pruneNames
        self.whitelist = whitelist
    }

    public func find() -> [ReportItem] {
        let candidates = collectCandidates()
        let bySize = Dictionary(grouping: candidates, by: { $0.size })
        var dupGroups: [[Candidate]] = []
        for (_, group) in bySize where group.count > 1 {
            let byHead = Dictionary(grouping: group) { headHash(of: $0.path) }
            for (_, sub) in byHead where sub.count > 1 {
                let byFull = Dictionary(grouping: sub) { fullHash(of: $0.path) }
                for (_, dupes) in byFull where dupes.count > 1 {
                    dupGroups.append(dupes)
                }
            }
        }

        var items: [ReportItem] = []
        for group in dupGroups {
            let sorted = group.sorted { ($0.mtime ?? .distantFuture) < ($1.mtime ?? .distantFuture) }
            guard let keeper = sorted.first else { continue }
            let groupId = UUID()
            items.append(ReportItem(
                path: keeper.path,
                size: keeper.size,
                tier: .review,
                category: "Duplicate",
                description: "Keeper (oldest copy in group)",
                lastModified: keeper.mtime,
                ruleId: "duplicate.keeper",
                groupId: groupId,
                keeperPath: keeper.path,
                isKeeper: true
            ))
            for dup in sorted.dropFirst() {
                items.append(ReportItem(
                    path: dup.path,
                    size: dup.size,
                    tier: .review,
                    category: "Duplicate",
                    description: "Duplicate of \((keeper.path as NSString).lastPathComponent)",
                    lastModified: dup.mtime,
                    ruleId: "duplicate.copy",
                    groupId: groupId,
                    keeperPath: keeper.path,
                    isKeeper: false
                ))
            }
        }
        return items
    }

    // MARK: - Internals

    struct Candidate {
        let path: String
        let size: Int64
        let mtime: Date?
    }

    private func collectCandidates() -> [Candidate] {
        var out: [Candidate] = []
        let fm = FileManager.default
        for root in roots {
            guard let enumerator = fm.enumerator(
                at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
                options: [.skipsHiddenFiles],
                errorHandler: { _, _ in true }
            ) else { continue }

            while let url = enumerator.nextObject() as? URL {
                let name = url.lastPathComponent
                if pruneNames.contains(name) {
                    enumerator.skipDescendants()
                    continue
                }
                guard let vals = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]),
                      vals.isRegularFile == true,
                      let size = vals.fileSize, Int64(size) >= minBytes else { continue }
                let path = url.path
                if whitelist.contains(path) { continue }
                out.append(Candidate(path: path, size: Int64(size), mtime: vals.contentModificationDate))
            }
        }
        return out
    }

    private func headHash(of path: String) -> String {
        guard let h = FileHandle(forReadingAtPath: path) else { return "" }
        defer { try? h.close() }
        let data = (try? h.read(upToCount: 8 * 1024)) ?? Data()
        return SHA256.hash(data: data).description
    }

    private func fullHash(of path: String) -> String {
        guard let h = FileHandle(forReadingAtPath: path) else { return "" }
        defer { try? h.close() }
        var hasher = SHA256()
        while autoreleasepool(invoking: {
            if let chunk = try? h.read(upToCount: 1024 * 1024), !chunk.isEmpty {
                hasher.update(data: chunk)
                return true
            }
            return false
        }) {}
        return hasher.finalize().description
    }
}
