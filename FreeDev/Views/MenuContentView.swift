import SwiftUI

struct MenuContentView: View {
    @Bindable var model: AppModel
    @State private var confirmingClean = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            versionBanner
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 400)
        .task { if model.items.isEmpty { await model.refresh() } }
        .confirmationDialog(
            "Clean \(model.selectedCount) item\(model.selectedCount == 1 ? "" : "s")?",
            isPresented: $confirmingClean, titleVisibility: .visible
        ) {
            Button("Reclaim \(ByteFormat.string(model.selectedReclaimable))", role: .destructive) {
                Task { await model.cleanSelected() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only regenerable caches and orphaned leftovers will be removed. Source code, archives, and in-use simulators are never touched.")
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Image("MenuBarIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 26, height: 26)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text("Free Dev").font(.system(size: 14, weight: .semibold))
                Text("Xcode & Simulator cleanup")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(ByteFormat.string(model.freeBytes))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("free on disk").font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: Version banner

    private var versionBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "globe").font(.system(size: 11)).foregroundStyle(.secondary)
            if let info = model.versionInfo {
                let build = info.latestBuild.map { " (\($0))" } ?? ""
                Text("Latest iOS **\(info.latestVersion)**\(build)")
                    .font(.system(size: 11))
                if !info.installedRuntimes.isEmpty {
                    Text("· sim \(info.installedRuntimes.joined(separator: ", "))")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(info.source).font(.system(size: 9)).foregroundStyle(.tertiary)
            } else {
                Text(model.isScanning ? "Checking latest iOS version…" : "iOS version unavailable")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.06))
    }

    // MARK: Content

    /// Snug height for the item list: fits the content, capped so the popover
    /// scrolls instead of growing without bound.
    private var listHeight: CGFloat {
        let rows = model.visibleGroups.reduce(0) { $0 + $1.items.count }
        let groups = model.visibleGroups.count
        let estimate = CGFloat(rows) * 56 + CGFloat(groups) * 26 + 16
        return min(estimate, 380)
    }

    @ViewBuilder
    private var content: some View {
        if model.items.isEmpty {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Scanning developer caches…")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        } else if model.items.allSatisfy({ !$0.exists }) {
            VStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 26)).foregroundStyle(.green)
                Text("Nothing to clean").font(.system(size: 13, weight: .medium))
                Text("No reclaimable Xcode leftovers found.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(model.visibleGroups, id: \.name) { section in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(section.name.uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 10)
                                .padding(.bottom, 1)
                            ForEach(section.items) { item in
                                ItemRow(item: item) { model.toggle(item) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
            }
            .frame(height: listHeight)
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 8) {
            if let message = model.statusMessage {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11)).foregroundStyle(.green)
                    Text(message).font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                }
            }

            HStack(spacing: 10) {
                Button {
                    Task { await model.refresh() }
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .disabled(model.isScanning || model.isCleaning)

                Spacer()

                if model.isCleaning {
                    ProgressView().controlSize(.small)
                }

                Button {
                    confirmingClean = true
                } label: {
                    Text(model.selectedCount > 0
                         ? "Clean \(model.selectedCount) · \(ByteFormat.string(model.selectedReclaimable))"
                         : "Clean")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.selectedCount == 0 || model.isScanning || model.isCleaning)
            }

            HStack {
                Button("Quit Free Dev") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
