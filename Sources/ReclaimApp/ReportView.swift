import SwiftUI
import ReclaimCore

struct ReportView: View {
    @ObservedObject var model: AppModel
    @State private var confirmDelete = false
    @State private var showDangerous = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Reclaim")
                        .font(.largeTitle).bold()
                    if let report = model.report {
                        Text("\(report.totalReclaimable.humanSize) reclaimable across \(report.items.count) items")
                            .foregroundStyle(.secondary)
                        Text("Scanned \(report.generated.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button(model.isScanning ? "Scanning…" : "Rescan") {
                    model.runScanNow()
                }.disabled(model.isScanning)
                if model.isScanning {
                    Button("Cancel") { model.cancelScan() }
                }
                Toggle("Show DANGEROUS tier", isOn: $showDangerous)
                    .toggleStyle(.checkbox)
            }
            if let p = model.scanProgress {
                ScanProgressLarge(progress: p)
            }
        }
        .padding()
    }

    @ViewBuilder
    private var content: some View {
        if let report = model.report {
            List {
                ForEach(visibleTiers(in: report), id: \.self) { tier in
                    let items = report.items.filter { $0.tier == tier }
                    let selectableIds = items.filter { !$0.isKeeper }.map(\.id)
                    Section {
                        ForEach(items) { item in
                            row(item)
                        }
                    } header: {
                        TierHeader(
                            tier: tier,
                            total: items.reduce(0) { $0 + $1.size },
                            selectableIds: selectableIds,
                            selectedIds: $model.selectedIds
                        )
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        } else {
            VStack {
                Spacer()
                Text("No report yet. Run a scan from the menu bar or click Rescan above.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            }
        }
    }

    private func visibleTiers(in report: Report) -> [Tier] {
        var tiers = Tier.allCases.sorted()
        if !showDangerous { tiers.removeAll { $0 == .dangerous } }
        return tiers.filter { tier in report.items.contains(where: { $0.tier == tier }) }
    }

    @ViewBuilder
    private func row(_ item: ReportItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle("", isOn: Binding(
                get: { model.selectedIds.contains(item.id) },
                set: { on in
                    if on { model.selectedIds.insert(item.id) }
                    else { model.selectedIds.remove(item.id) }
                }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            .disabled(item.isKeeper)
            .help(item.isKeeper ? "Keeper — protected from deletion" : "")

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.description).bold()
                    if item.isKeeper {
                        Text("KEEPER")
                            .font(.caption2).bold()
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Color.green.opacity(0.2))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                }
                Text(item.path)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 8) {
                    Label(item.category, systemImage: "folder")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if let m = item.lastModified {
                        Label(m.formatted(date: .abbreviated, time: .omitted), systemImage: "clock")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            Text(item.size.humanSize)
                .font(.system(.body, design: .monospaced))
                .bold()
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
            }
            Button("Whitelist this path") {
                model.whitelistStore.add(path: item.path)
                model.loadReport()
            }
            Button("Whitelist by name (glob */name)") {
                let name = (item.path as NSString).lastPathComponent
                model.whitelistStore.add(glob: "*/\(name)")
                model.loadReport()
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        HStack {
            Text(selectionSummary)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Whitelist Selected") {
                model.whitelistSelected(asGlob: false)
            }
            .disabled(model.selectedIds.isEmpty)

            Button("Move to Trash") {
                confirmDelete = true
            }
            .keyboardShortcut(.delete)
            .disabled(model.selectedIds.isEmpty || requiresDangerousConfirm)
            .tint(.red)
        }
        .padding()
        .alert("Move selected items to Trash?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Move to Trash", role: .destructive) {
                model.trashSelected()
            }
        } message: {
            Text("\(model.selectedIds.count) items will move to the Trash. You can restore them from there.")
        }
    }

    private var selectionSummary: String {
        guard let report = model.report else { return "" }
        let chosen = report.items.filter { model.selectedIds.contains($0.id) }
        let total = chosen.reduce(Int64(0)) { $0 + $1.size }
        return "\(chosen.count) selected · \(total.humanSize)"
    }

    private var requiresDangerousConfirm: Bool {
        guard let report = model.report else { return false }
        return report.items.contains { model.selectedIds.contains($0.id) && $0.tier == .dangerous }
    }
}

struct ScanProgressLarge: View {
    let progress: ScanProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Scanning — \(progress.phase)").bold()
                Spacer()
                if progress.total > 0 {
                    Text("\(progress.current) / \(progress.total)  ·  \(Int(progress.fraction * 100))%")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            ProgressView(value: progress.fraction)
                .progressViewStyle(.linear)
            Text(progress.label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct TierHeader: View {
    let tier: Tier
    let total: Int64
    let selectableIds: [UUID]
    @Binding var selectedIds: Set<UUID>

    private var allSelected: Bool {
        !selectableIds.isEmpty && selectableIds.allSatisfy { selectedIds.contains($0) }
    }

    private var partiallySelected: Bool {
        let any = selectableIds.contains { selectedIds.contains($0) }
        return any && !allSelected
    }

    var body: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: Binding(
                get: { allSelected },
                set: { on in
                    if on { selectedIds.formUnion(selectableIds) }
                    else { selectedIds.subtract(selectableIds) }
                }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            .disabled(selectableIds.isEmpty)
            .help(allSelected ? "Deselect all in this section"
                  : partiallySelected ? "Select all in this section (some selected)"
                  : "Select all in this section")

            Circle().fill(color).frame(width: 10, height: 10)
            Text(tier.label).bold()
            if partiallySelected {
                Text("(partial)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(total.humanSize).font(.system(.body, design: .monospaced))
        }
    }

    private var color: Color {
        switch tier {
        case .safe: return .green
        case .review: return .yellow
        case .heuristic: return .orange
        case .dangerous: return .red
        }
    }
}
