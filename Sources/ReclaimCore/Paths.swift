import Foundation

public enum Paths {
    public static let supportDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Reclaim", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    public static var reportURL: URL { supportDir.appendingPathComponent("report.json") }
    public static var whitelistURL: URL { supportDir.appendingPathComponent("whitelist.json") }
    public static var historyURL: URL { supportDir.appendingPathComponent("history.json") }
    public static var logURL: URL { supportDir.appendingPathComponent("scanner.log") }
    public static var progressURL: URL { supportDir.appendingPathComponent("progress.json") }

    public static func expand(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }

    public static var home: String { NSHomeDirectory() }
}
