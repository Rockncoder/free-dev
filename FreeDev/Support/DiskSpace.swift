import Foundation

enum DiskSpace {
    /// Free bytes on the volume containing the user's home directory,
    /// using the "important usage" capacity (what the Finder reports as available).
    static func freeBytes() -> Int64 {
        let url = FileManager.default.homeDirectoryForCurrentUser
        if let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let capacity = values.volumeAvailableCapacityForImportantUsage {
            return capacity
        }
        // Fallback to the plain available capacity.
        if let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityKey]),
           let capacity = values.volumeAvailableCapacity {
            return Int64(capacity)
        }
        return 0
    }

    /// Size of a file/directory on disk, in bytes. Returns 0 if missing.
    static func sizeOnDisk(_ path: String) -> Int64 {
        guard FileManager.default.fileExists(atPath: path) else { return 0 }
        // `du -sk` is dramatically faster than a Swift file enumerator on large trees.
        // Generous timeout for huge folders, but bounded so it can't hang the scan.
        let result = Shell.run("/usr/bin/du", ["-sk", path], timeout: 90)
        guard result.status == 0 || !result.stdout.isEmpty else { return 0 }
        let firstToken = result.stdout.split(whereSeparator: { $0 == "\t" || $0 == " " }).first
        guard let kb = firstToken.flatMap({ Int64($0) }) else { return 0 }
        return kb * 1024
    }
}
