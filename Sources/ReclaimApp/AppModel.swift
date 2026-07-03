import Foundation
import SwiftUI
import ReclaimCore

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var report: Report?
    @Published var selectedIds: Set<UUID> = []
    @Published var lastScanError: String?
    @Published var isScanning: Bool = false
    @Published var scanProgress: ScanProgress?
    @Published var scanOptions: ScanOptions = ScanOptions.load() {
        didSet { try? scanOptions.save() }
    }

    let whitelistStore = WhitelistStore()
    private var scannerProcess: Process?
    private var reportWatcher: DispatchSourceFileSystemObject?
    private var progressWatcher: DispatchSourceFileSystemObject?
    private var progressDirWatcher: DispatchSourceFileSystemObject?
    private var progressPollTimer: Timer?

    init() {
        loadReport()
        loadProgress()
        watchReport()
        watchProgressDirectory()
    }

    func loadReport() {
        self.report = Report.load()
    }

    func loadProgress() {
        let next = ScanProgress.load()
        self.scanProgress = next
        // Treat presence of progress file as "scanning" indicator.
        self.isScanning = (next != nil)
    }

    private func watchReport() {
        let url = Paths.reportURL
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .extend],
            queue: .main
        )
        src.setEventHandler { [weak self] in
            self?.loadReport()
        }
        src.setCancelHandler { close(fd) }
        src.resume()
        self.reportWatcher = src
    }

    /// Watch the support directory so we can attach/detach progress watchers
    /// as the progress file is created/deleted across scans.
    private func watchProgressDirectory() {
        let dir = Paths.supportDir.path
        let fd = open(dir, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write],
            queue: .main
        )
        src.setEventHandler { [weak self] in
            guard let self else { return }
            self.attachProgressWatcherIfNeeded()
            self.loadProgress()
        }
        src.setCancelHandler { close(fd) }
        src.resume()
        self.progressDirWatcher = src
        attachProgressWatcherIfNeeded()
    }

    private func attachProgressWatcherIfNeeded() {
        let url = Paths.progressURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            progressWatcher?.cancel()
            progressWatcher = nil
            return
        }
        if progressWatcher != nil { return }
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .extend],
            queue: .main
        )
        src.setEventHandler { [weak self] in
            self?.loadProgress()
        }
        src.setCancelHandler {
            close(fd)
        }
        src.resume()
        self.progressWatcher = src
    }

    func runScanNow() {
        guard !isScanning else { return }
        try? scanOptions.save() // scanner reads this file at launch
        isScanning = true
        lastScanError = nil
        scanProgress = ScanProgress(phase: "starting", current: 0, total: 1, label: "Launching scanner…")
        Task.detached(priority: .userInitiated) {
            let scannerPath = await Self.scannerBinaryPath()
            let proc = Process()
            proc.launchPath = scannerPath
            do { try proc.run() } catch {
                await MainActor.run {
                    self.lastScanError = "Failed to launch scanner: \(error.localizedDescription)"
                    self.scannerProcess = nil
                    self.isScanning = false
                    self.scanProgress = nil
                }
                return
            }
            await MainActor.run { self.scannerProcess = proc }
            proc.waitUntilExit()
            await MainActor.run {
                self.scannerProcess = nil
                self.loadReport()
                self.loadProgress() // will set isScanning=false if progress file gone
            }
        }
    }

    /// Stop an in-progress scan: kill the scanner process, remove the progress
    /// file, and reset UI state. Safe to call even if the process already died
    /// or was never tracked (e.g. a stale progress file from a crashed scan).
    func cancelScan() {
        if let proc = scannerProcess, proc.isRunning {
            proc.terminate()
        }
        scannerProcess = nil
        // Scanner won't clear its own progress file if killed, so do it here.
        try? FileManager.default.removeItem(at: Paths.progressURL)
        isScanning = false
        scanProgress = nil
        lastScanError = nil
    }

    static func scannerBinaryPath() -> String {
        let support = Paths.supportDir.appendingPathComponent("bin/reclaim-scanner").path
        if FileManager.default.fileExists(atPath: support) { return support }
        // Fallback: assume sibling to app binary.
        let exe = Bundle.main.executableURL?.deletingLastPathComponent()
            .appendingPathComponent("reclaim-scanner").path
        return exe ?? "/usr/local/bin/reclaim-scanner"
    }

    func trashSelected() {
        guard let report else { return }
        // Never trash a keeper item, even if user checked it by accident.
        let selected = report.items.filter { selectedIds.contains($0.id) && !$0.isKeeper }
        let results = Trasher.trashAll(selected.map(\.path))
        let trashedPaths = Set(results.compactMap { $0.error == nil ? $0.path : nil })
        let remaining = report.items.filter { !trashedPaths.contains($0.path) }
        self.report = Report(generated: report.generated, items: remaining)
        try? self.report?.save()
        selectedIds.removeAll()
    }

    func whitelistSelected(asGlob: Bool = false) {
        guard let report else { return }
        let selected = report.items.filter { selectedIds.contains($0.id) }
        for item in selected {
            if asGlob {
                let pattern = "*/\((item.path as NSString).lastPathComponent)"
                whitelistStore.add(glob: pattern)
            } else {
                whitelistStore.add(path: item.path)
            }
        }
        let selectedPaths = Set(selected.map(\.path))
        let remaining = report.items.filter { !selectedPaths.contains($0.path) }
        self.report = Report(generated: report.generated, items: remaining)
        try? self.report?.save()
        selectedIds.removeAll()
    }
}
