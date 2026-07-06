import Foundation

/// Executes cleanup actions. Uses FileManager (not `rm -rf`) and only ever
/// touches paths inside the user's own `~/Library/Developer` tree or lets
/// `simctl` remove devices it has itself flagged as unavailable.
enum Cleaner {
    struct Outcome {
        var freedBytes: Int64 = 0
        var errors: [String] = []
    }

    /// Guard: refuse to operate outside the expected developer/cache roots.
    static func isSafePath(_ path: String) -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let allowedRoots = [
            "\(home)/Library/Developer/",
            "\(home)/Library/Caches/",
            "\(home)/.npm/",
            "\(home)/.pub-cache/",
        ]
        let standardized = (path as NSString).standardizingPath
        return allowedRoots.contains { standardized.hasPrefix($0) }
    }

    /// Number of discrete steps `perform` will take for this action — used to
    /// drive the cleaning progress bar.
    static func unitCount(for action: CleanupItem.Action) -> Int {
        let fm = FileManager.default
        switch action {
        case let .emptyDirectory(path):
            guard isSafePath(path), let children = try? fm.contentsOfDirectory(atPath: path) else { return 0 }
            return children.count
        case let .deletePaths(paths):
            return paths.filter { isSafePath($0) && fm.fileExists(atPath: $0) }.count
        case .deleteOrphanedSimulators:
            return 1
        case let .deleteRuntimes(identifiers):
            return max(1, identifiers.count)
        }
    }

    /// - Parameter onUnit: called once per removed child/path/runtime so the UI
    ///   can advance a progress bar during long deletes.
    static func perform(_ action: CleanupItem.Action, onUnit: (() -> Void)? = nil) -> Outcome {
        var outcome = Outcome()
        let fm = FileManager.default

        switch action {
        case let .emptyDirectory(path):
            guard isSafePath(path), fm.fileExists(atPath: path) else { return outcome }
            let before = DiskSpace.sizeOnDisk(path)
            guard let children = try? fm.contentsOfDirectory(atPath: path) else { return outcome }
            for child in children {
                let full = (path as NSString).appendingPathComponent(child)
                do { try fm.removeItem(atPath: full) }
                catch { outcome.errors.append("\(child): \(error.localizedDescription)") }
                onUnit?()
            }
            outcome.freedBytes = max(0, before - DiskSpace.sizeOnDisk(path))

        case let .deletePaths(paths):
            for path in paths {
                guard isSafePath(path), fm.fileExists(atPath: path) else { continue }
                let size = DiskSpace.sizeOnDisk(path)
                do {
                    try fm.removeItem(atPath: path)
                    outcome.freedBytes += size
                } catch {
                    outcome.errors.append("\((path as NSString).lastPathComponent): \(error.localizedDescription)")
                }
                onUnit?()
            }

        case let .deleteOrphanedSimulators(dataPaths):
            let before = dataPaths.reduce(Int64(0)) { $0 + DiskSpace.sizeOnDisk($1) }
            if SimulatorService.deleteOrphaned() {
                outcome.freedBytes = before
            } else {
                outcome.errors.append("simctl could not delete unavailable simulators")
            }
            onUnit?()

        case let .deleteRuntimes(identifiers):
            // Re-read sizes now so the freed total reflects what actually existed.
            let sizeByID = Dictionary(
                SimulatorService.runtimeImages().map { ($0.identifier, $0.sizeBytes) },
                uniquingKeysWith: { first, _ in first })
            for identifier in identifiers {
                if SimulatorService.deleteRuntime(identifier) {
                    outcome.freedBytes += sizeByID[identifier] ?? 0
                } else {
                    outcome.errors.append("could not delete runtime \(identifier)")
                }
                onUnit?()
            }
        }
        return outcome
    }
}
