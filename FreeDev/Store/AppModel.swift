import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    var items: [CleanupItem] = []
    var freeBytes: Int64 = 0
    var versionInfo: VersionService.Info?

    var isScanning = false
    var isCleaning = false
    var statusMessage: String?
    /// 0…1 progress of the current scan (fraction of categories measured).
    var scanProgress: Double = 0
    /// 0…1 progress of the current clean (fraction of items removed).
    var cleanProgress: Double = 0
    private var cleanUnitsDone = 0

    private let home = FileManager.default.homeDirectoryForCurrentUser.path

    /// Section display order.
    static let groupOrder = ["Xcode", "Simulators", "Package Managers"]

    /// Visible (existing) items grouped into ordered, non-empty sections.
    var visibleGroups: [(name: String, items: [CleanupItem])] {
        let visible = items.filter(\.exists)
        return AppModel.groupOrder.compactMap { name in
            let groupItems = visible.filter { $0.group == name }
            return groupItems.isEmpty ? nil : (name, groupItems)
        }
    }

    var totalReclaimable: Int64 {
        items.filter(\.exists).reduce(0) { $0 + $1.reclaimableBytes }
    }

    var selectedReclaimable: Int64 {
        items.filter { $0.selected && $0.exists }.reduce(0) { $0 + $1.reclaimableBytes }
    }

    var selectedCount: Int {
        items.filter { $0.selected && $0.exists }.count
    }

    // MARK: Scanning

    func refresh() async {
        guard !isScanning, !isCleaning else { return }
        isScanning = true
        scanProgress = 0
        statusMessage = nil
        freeBytes = DiskSpace.freeBytes()

        async let version = VersionService.fetch()
        let scanned = await DiskScanner.scan(home: home) { [weak self] done, total in
            let fraction = total > 0 ? Double(done) / Double(total) : 0
            Task { @MainActor in
                guard let self else { return }
                self.scanProgress = max(self.scanProgress, fraction)
            }
        }

        items = scanned
        scanProgress = 1
        versionInfo = await version
        freeBytes = DiskSpace.freeBytes()
        isScanning = false
    }

    func toggle(_ item: CleanupItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].selected.toggle()
    }

    // MARK: Cleaning

    func cleanSelected() async {
        guard !isCleaning, !isScanning else { return }
        let targets = items.filter { $0.selected && $0.exists }
        guard !targets.isEmpty else { return }

        isCleaning = true
        cleanProgress = 0
        cleanUnitsDone = 0
        statusMessage = nil
        let freeBefore = DiskSpace.freeBytes()

        let totalUnits = max(1, targets.reduce(0) { $0 + Cleaner.unitCount(for: $1.action) })

        var freed: Int64 = 0
        var errors: [String] = []
        for target in targets {
            let action = target.action
            let outcome = await Task.detached {
                Cleaner.perform(action) { [weak self] in
                    Task { @MainActor in
                        guard let self else { return }
                        self.cleanUnitsDone += 1
                        self.cleanProgress = min(1, Double(self.cleanUnitsDone) / Double(totalUnits))
                    }
                }
            }.value
            freed += outcome.freedBytes
            errors.append(contentsOf: outcome.errors)
        }

        cleanProgress = 1
        isCleaning = false
        await refresh()

        let reclaimed = max(freed, DiskSpace.freeBytes() - freeBefore)
        if errors.isEmpty {
            statusMessage = "Reclaimed \(ByteFormat.string(reclaimed))."
        } else {
            statusMessage = "Reclaimed \(ByteFormat.string(reclaimed)) · \(errors.count) item(s) skipped."
        }
    }
}
