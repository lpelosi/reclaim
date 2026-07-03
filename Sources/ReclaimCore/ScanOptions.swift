import Foundation

/// User-tunable scan settings, persisted to the support dir. The app writes
/// these from the report-window checkboxes; the scanner reads them at launch,
/// so both manual and scheduled (launchd) scans honor the same choices.
public struct ScanOptions: Codable, Equatable {
    /// Opt-in: flag large individual files (Review tier — often personal).
    public var scanLargeFiles: Bool
    /// Opt-in: flag large folders (Review tier).
    public var scanLargeDirs: Bool
    /// Duplicate-file scan (on by default; the slowest step).
    public var scanDuplicates: Bool
    /// Opt-in: flag old, sizeable files not modified in `oldFileDays` (Review).
    public var flagOldFiles: Bool
    /// Extend large/dup/old scans into mounted /Volumes drives.
    public var includeExternalDrives: Bool
    /// Minimum size for a "large" file or folder.
    public var minLargeBytes: Int64
    /// Age (days) past which a file counts as "old".
    public var oldFileDays: Int
    /// Roots the large/old scans walk (tilde paths).
    public var roots: [String]

    /// Old files must also clear this floor so the list stays useful.
    public static let oldFileMinBytes: Int64 = 100_000_000

    /// Roots offered in the UI picker.
    public static let availableRoots = [
        "~/Downloads", "~/Desktop", "~/Documents", "~/Movies", "~/Pictures", "~"
    ]
    public static let defaultRoots = ["~/Downloads", "~/Desktop", "~/Documents", "~/Movies"]

    public init(
        scanLargeFiles: Bool = false,
        scanLargeDirs: Bool = false,
        scanDuplicates: Bool = true,
        flagOldFiles: Bool = false,
        includeExternalDrives: Bool = false,
        minLargeBytes: Int64 = 500_000_000,
        oldFileDays: Int = 365,
        roots: [String] = ScanOptions.defaultRoots
    ) {
        self.scanLargeFiles = scanLargeFiles
        self.scanLargeDirs = scanLargeDirs
        self.scanDuplicates = scanDuplicates
        self.flagOldFiles = flagOldFiles
        self.includeExternalDrives = includeExternalDrives
        self.minLargeBytes = minLargeBytes
        self.oldFileDays = oldFileDays
        self.roots = roots
    }

    public static func load(from url: URL = Paths.scanOptionsURL) -> ScanOptions {
        guard let data = try? Data(contentsOf: url),
              let opts = try? JSONDecoder().decode(ScanOptions.self, from: data)
        else { return ScanOptions() }
        return opts
    }

    public func save(to url: URL = Paths.scanOptionsURL) throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(self).write(to: url, options: .atomic)
    }
}
