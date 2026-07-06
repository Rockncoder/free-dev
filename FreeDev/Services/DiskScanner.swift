import Foundation

/// Builds the list of cleanable items and measures each concurrently.
///
/// Everything here targets ONLY regenerable caches or orphaned/redundant
/// leftovers. Items whose location doesn't exist are marked `exists == false`
/// and hidden by the UI (auto-hide). Risky items are `.caution` and never
/// selected by default.
enum DiskScanner {
    /// - Parameter onProgress: called as each category finishes measuring, with
    ///   `(completed, total)`. Runs off the main actor — hop to `@MainActor` to
    ///   update UI state.
    static func scan(home: String,
                     onProgress: (@Sendable (Int, Int) -> Void)? = nil) async -> [CleanupItem] {
        let library = "\(home)/Library"
        let developer = "\(library)/Developer"

        // Each spec builds one item (measuring its size when run).
        var specs: [() -> CleanupItem] = []

        /// "Empty this cache directory" item — safe & regenerable by default.
        func cacheItem(group: String, id: String, title: String, detail: String,
                       path: String, safety: CleanupItem.Safety = .safe) -> () -> CleanupItem {
            {
                let size = DiskSpace.sizeOnDisk(path)
                let exists = FileManager.default.fileExists(atPath: path) && size > 0
                return CleanupItem(
                    group: group, id: id, title: title, detail: detail,
                    safety: safety, action: .emptyDirectory(path: path),
                    reclaimableBytes: size, exists: exists,
                    selected: exists && safety == .safe, note: nil)
            }
        }

        // MARK: Xcode

        specs.append(cacheItem(group: "Xcode", id: "derived-data", title: "Derived Data",
            detail: "Build intermediates and indexes. Xcode rebuilds these on the next build.",
            path: "\(developer)/Xcode/DerivedData"))
        specs.append(cacheItem(group: "Xcode", id: "xcode-caches", title: "Xcode Caches",
            detail: "Xcode's own on-disk cache. Regenerated automatically.",
            path: "\(library)/Caches/com.apple.dt.Xcode"))
        specs.append(cacheItem(group: "Xcode", id: "swiftpm-caches", title: "Swift Package Caches",
            detail: "Cached Swift Package checkouts. Re-fetched on demand.",
            path: "\(library)/Caches/org.swift.swiftpm"))
        specs.append(cacheItem(group: "Xcode", id: "device-logs", title: "iOS Device Logs",
            detail: "Crash / diagnostic logs pulled from attached devices.",
            path: "\(developer)/Xcode/iOS Device Logs"))

        // Old device symbols — one item per OS DeviceSupport folder present.
        for os in ["iOS", "watchOS", "tvOS", "xrOS"] {
            let dir = "\(developer)/Xcode/\(os) DeviceSupport"
            let displayOS = (os == "xrOS") ? "visionOS" : os
            specs.append {
                // Only symbols for OS versions OLDER than the newest are stale;
                // multiple devices on the current OS are all kept.
                let stalePaths = DeviceSupport.staleFolders(in: dir)
                    .map { (dir as NSString).appendingPathComponent($0) }
                let reclaimable = stalePaths.reduce(Int64(0)) { $0 + DiskSpace.sizeOnDisk($1) }
                let exists = !stalePaths.isEmpty && reclaimable > 0
                return CleanupItem(
                    group: "Xcode", id: "device-support-\(os)",
                    title: "Old \(displayOS) Symbols",
                    detail: "Debug symbols for older \(displayOS) versions. Re-downloaded when a device reconnects.",
                    safety: .caution, action: .deletePaths(paths: stalePaths),
                    reclaimableBytes: reclaimable, exists: exists, selected: false,
                    note: DeviceSupport.maxVersion(in: dir).map { "keeps \($0)" })
            }
        }

        specs.append(cacheItem(group: "Xcode", id: "archives", title: "Xcode Archives",
            detail: "Shipped build archives & dSYMs. Only remove if you won't need to re-export or symbolicate them.",
            path: "\(developer)/Xcode/Archives", safety: .caution))

        // MARK: Simulators

        specs.append(cacheItem(group: "Simulators", id: "sim-caches", title: "Simulator Caches",
            detail: "CoreSimulator scratch caches. Recreated when simulators run.",
            path: "\(developer)/CoreSimulator/Caches"))

        specs.append {
            let paths = SimulatorService.orphanedDataPaths()
            let size = paths.reduce(Int64(0)) { $0 + DiskSpace.sizeOnDisk($1) }
            return CleanupItem(
                group: "Simulators", id: "orphaned-sims", title: "Orphaned Simulators",
                detail: "Simulator devices whose runtime no longer exists. Removes only these.",
                safety: .safe, action: .deleteOrphanedSimulators(dataPaths: paths),
                reclaimableBytes: size, exists: !paths.isEmpty, selected: !paths.isEmpty,
                note: paths.isEmpty ? nil : "\(paths.count) device\(paths.count == 1 ? "" : "s")")
        }

        specs.append {
            let images = SimulatorService.runtimeImages()
            // Keep the newest version per platform; everything else deletable goes.
            var newest: [String: SimulatorService.RuntimeImage] = [:]
            for image in images {
                if let current = newest[image.platform] {
                    if SemanticVersion.greater(image.version, than: current.version) {
                        newest[image.platform] = image
                    }
                } else {
                    newest[image.platform] = image
                }
            }
            let toDelete = images.filter {
                $0.deletable && newest[$0.platform]?.identifier != $0.identifier
            }
            let reclaim = toDelete.reduce(Int64(0)) { $0 + $1.sizeBytes }
            return CleanupItem(
                group: "Simulators", id: "old-runtimes", title: "Old Simulator Runtimes",
                detail: "Downloaded runtime images older than the newest per platform. Re-downloadable in Xcode.",
                safety: .caution, action: .deleteRuntimes(identifiers: toDelete.map { $0.identifier }),
                reclaimableBytes: reclaim, exists: !toDelete.isEmpty && reclaim > 0, selected: false,
                note: toDelete.isEmpty ? nil : "\(toDelete.count) runtime\(toDelete.count == 1 ? "" : "s")")
        }

        // MARK: Package Managers (auto-hidden when the cache is absent)

        specs.append(cacheItem(group: "Package Managers", id: "homebrew", title: "Homebrew Cache",
            detail: "Downloaded bottles & formula cache. Re-downloaded on demand.",
            path: "\(library)/Caches/Homebrew"))
        specs.append(cacheItem(group: "Package Managers", id: "cocoapods", title: "CocoaPods Cache",
            detail: "Cached pod specs & downloads. Re-fetched on demand.",
            path: "\(library)/Caches/CocoaPods"))
        specs.append(cacheItem(group: "Package Managers", id: "carthage", title: "Carthage Cache",
            detail: "Cached Carthage builds & checkouts. Re-fetched on demand.",
            path: "\(library)/Caches/org.carthage.CarthageKit"))
        specs.append(cacheItem(group: "Package Managers", id: "npm", title: "npm Cache",
            detail: "npm's content-addressable download cache. Re-fetched on demand.",
            path: "\(home)/.npm/_cacache"))
        specs.append(cacheItem(group: "Package Managers", id: "yarn", title: "Yarn Cache",
            detail: "Yarn's package cache. Re-fetched on demand.",
            path: "\(library)/Caches/Yarn"))
        specs.append(cacheItem(group: "Package Managers", id: "pnpm", title: "pnpm Cache",
            detail: "pnpm's package cache. Re-fetched on demand.",
            path: "\(library)/Caches/pnpm"))
        specs.append(cacheItem(group: "Package Managers", id: "pub-cache", title: "Dart / Flutter Packages",
            detail: "Downloaded Dart & Flutter packages. Re-fetched with `pub get` (keeps globally-activated tools).",
            path: "\(home)/.pub-cache/hosted"))

        // Run each (blocking) measurement on a GCD thread rather than the Swift
        // cooperative pool — a slow/hung command then can't starve concurrency,
        // and combined with Shell.run's hard timeout the scan always finishes.
        let total = specs.count
        return await withTaskGroup(of: (Int, CleanupItem).self) { group in
            for (index, make) in specs.enumerated() {
                group.addTask {
                    await withCheckedContinuation { (cont: CheckedContinuation<(Int, CleanupItem), Never>) in
                        DispatchQueue.global(qos: .userInitiated).async {
                            cont.resume(returning: (index, make()))
                        }
                    }
                }
            }
            var collected: [(Int, CleanupItem)] = []
            onProgress?(0, total)
            for await result in group {
                collected.append(result)
                onProgress?(collected.count, total)
            }
            return collected.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }
}
