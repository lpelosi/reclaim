import Foundation

public struct Whitelist: Codable {
    public var paths: Set<String>
    public var globs: Set<String>

    public init(paths: Set<String> = [], globs: Set<String> = []) {
        self.paths = paths
        self.globs = globs
    }

    public func contains(_ path: String) -> Bool {
        if paths.contains(path) { return true }
        for g in globs {
            if fnmatch(g, path) { return true }
        }
        return false
    }

    private func fnmatch(_ pattern: String, _ str: String) -> Bool {
        var p = pattern.cString(using: .utf8)!
        var s = str.cString(using: .utf8)!
        return Darwin.fnmatch(&p, &s, 0) == 0
    }
}

public final class WhitelistStore {
    public private(set) var whitelist: Whitelist
    private let url: URL

    public init(url: URL = Paths.whitelistURL) {
        self.url = url
        if let data = try? Data(contentsOf: url),
           let wl = try? JSONDecoder().decode(Whitelist.self, from: data) {
            self.whitelist = wl
        } else {
            self.whitelist = Whitelist()
        }
    }

    public func add(path: String) {
        whitelist.paths.insert(path)
        save()
    }

    public func add(glob: String) {
        whitelist.globs.insert(glob)
        save()
    }

    public func remove(path: String) {
        whitelist.paths.remove(path)
        save()
    }

    public func remove(glob: String) {
        whitelist.globs.remove(glob)
        save()
    }

    public func save() {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(whitelist) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
