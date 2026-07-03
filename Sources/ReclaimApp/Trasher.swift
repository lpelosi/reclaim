import Foundation
import AppKit

public enum TrashError: Error {
    case failed(String, underlying: Error?)
}

public enum Trasher {
    /// Move path to user's Trash (reversible).
    public static func trash(_ path: String) throws {
        let url = URL(fileURLWithPath: path)
        var resulting: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resulting)
    }

    public static func trashAll(_ paths: [String]) -> [(path: String, error: Error?)] {
        var results: [(String, Error?)] = []
        for p in paths {
            do {
                try trash(p)
                results.append((p, nil))
            } catch {
                results.append((p, error))
            }
        }
        return results
    }
}
