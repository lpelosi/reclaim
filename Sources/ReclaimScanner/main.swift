import Foundation
import ReclaimCore
#if canImport(UserNotifications)
import UserNotifications
#endif

let store = WhitelistStore()
let progress = ProgressReporter()
let options = ScanOptions.load()
let scanner = Scanner(whitelist: store.whitelist, reporter: progress, options: options)

let started = Date()
log("scan started")
let report = scanner.run()

do {
    try report.save()
    log("wrote report: \(report.items.count) items, \(report.totalReclaimable.humanSize) reclaimable")
} catch {
    log("ERROR writing report: \(error)")
    progress.clear()
    exit(1)
}

progress.clear()
let elapsed = Date().timeIntervalSince(started)
log(String(format: "scan complete in %.1fs", elapsed))

postNotification(total: report.totalReclaimable, count: report.items.count)

func log(_ msg: String) {
    let ts = ISO8601DateFormatter().string(from: Date())
    let line = "[\(ts)] \(msg)\n"
    if let data = line.data(using: .utf8) {
        if let handle = try? FileHandle(forWritingTo: Paths.logURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: Paths.logURL)
        }
    }
    FileHandle.standardError.write((line).data(using: .utf8)!)
}

func postNotification(total: Int64, count: Int) {
    // Make sure the Reclaim menubar app is running so it can surface the
    // notification via UNUserNotificationCenter (proper bundle = proper
    // icon + identity, instead of "Script Editor" via osascript).
    ensureAppRunning()

    // Give the app a moment to register its DistributedNotificationCenter
    // observer if we just launched it.
    Thread.sleep(forTimeInterval: 1.5)

    DistributedNotificationCenter.default().postNotificationName(
        Notification.Name("com.reclaim.scanComplete"),
        object: nil,
        userInfo: nil,
        deliverImmediately: true
    )
}

func ensureAppRunning() {
    // pgrep returns 0 if a match exists.
    let check = Process()
    check.launchPath = "/usr/bin/pgrep"
    check.arguments = ["-f", "Reclaim.app/Contents/MacOS/ReclaimApp"]
    check.standardOutput = Pipe()
    check.standardError = Pipe()
    do { try check.run() } catch { return }
    check.waitUntilExit()
    if check.terminationStatus == 0 { return }

    // Locate the .app bundle (scanner lives inside Contents/MacOS/).
    let scannerPath = CommandLine.arguments[0]
    let scannerURL = URL(fileURLWithPath: scannerPath).resolvingSymlinksInPath()
    let appURL = scannerURL
        .deletingLastPathComponent() // MacOS
        .deletingLastPathComponent() // Contents
        .deletingLastPathComponent() // Reclaim.app
    guard FileManager.default.fileExists(atPath: appURL.path) else { return }

    let open = Process()
    open.launchPath = "/usr/bin/open"
    open.arguments = ["-g", appURL.path] // -g = launch without bringing to front
    try? open.run()
    open.waitUntilExit()
}
