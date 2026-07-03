import SwiftUI
import ReclaimCore

struct MenuBarView: View {
    @ObservedObject var model: AppModel
    @State private var launchAtLogin: Bool = LoginItem.isEnabled
    @State private var loginItemError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let report = model.report {
                Text("Reclaim")
                    .font(.headline)
                Text("\(report.totalReclaimable.humanSize) reclaimable")
                    .font(.title3)
                    .bold()
                Text("\(report.items.count) items")
                    .foregroundStyle(.secondary)
                Text("Scanned: \(report.generated.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No report yet")
                    .foregroundStyle(.secondary)
            }

            if let p = model.scanProgress {
                Divider()
                ScanProgressMini(progress: p)
            }

            if let err = model.lastScanError {
                Text(err).font(.caption).foregroundStyle(.red)
            }

            Divider()

            Button("Open Report…") {
                (NSApp.delegate as? AppDelegate)?.showReportWindow()
            }

            if model.isScanning {
                HStack(spacing: 8) {
                    Button("Scanning…") { model.runScanNow() }
                        .disabled(true)
                    Button("Cancel Scan") { model.cancelScan() }
                }
            } else {
                Button("Run Scan Now") { model.runScanNow() }
            }

            Divider()

            Toggle("Launch at login", isOn: $launchAtLogin)
                .toggleStyle(.checkbox)
                .onChange(of: launchAtLogin) { newValue in
                    do {
                        try LoginItem.setEnabled(newValue)
                        loginItemError = nil
                    } catch {
                        loginItemError = error.localizedDescription
                        launchAtLogin = LoginItem.isEnabled
                    }
                }
            if let err = loginItemError {
                Text(err).font(.caption2).foregroundStyle(.red)
            }

            Divider()

            Button("Quit Reclaim") {
                NSApp.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 300)
    }
}

struct ScanProgressMini: View {
    let progress: ScanProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Scanning — \(progress.phase)").font(.caption).bold()
                Spacer()
                if progress.total > 0 {
                    Text("\(progress.current)/\(progress.total)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            ProgressView(value: progress.fraction)
                .progressViewStyle(.linear)
            Text(progress.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
