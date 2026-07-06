import Foundation

/// One cleanable category of Xcode / Simulator leftovers.
///
/// Safety contract: every action here targets ONLY regenerable caches or
/// orphaned leftovers. Nothing removes source code, shipped archives, or the
/// data of simulators that are still usable.
struct CleanupItem: Identifiable {
    enum Safety {
        /// Regenerated automatically or truly orphaned — always safe to remove.
        case safe
        /// Recoverable but has a cost (e.g. re-downloaded on next connect).
        /// Never selected by default.
        case caution
    }

    enum Action {
        /// Delete the *children* of a directory, keeping the directory itself.
        case emptyDirectory(path: String)
        /// Delete a specific set of files/folders (each re-checked against the
        /// safe-path allowlist before removal).
        case deletePaths(paths: [String])
        /// `xcrun simctl delete unavailable` — removes only orphaned devices
        /// whose runtime no longer exists.
        case deleteOrphanedSimulators(dataPaths: [String])
        /// `xcrun simctl runtime delete <id>` for each — removes downloaded
        /// simulator runtime images (keeping the newest per platform).
        case deleteRuntimes(identifiers: [String])
    }

    /// Section the item is shown under (see `AppModel.groupOrder`).
    let group: String
    let id: String
    let title: String
    let detail: String
    let safety: Safety
    let action: Action

    /// Bytes that would actually be freed by running the action.
    var reclaimableBytes: Int64
    /// Whether the underlying location exists and has anything to reclaim.
    var exists: Bool
    /// Whether the user has this item ticked for cleaning.
    var selected: Bool
    /// Short annotation shown under the title (e.g. "keeps 26.5", "3 devices").
    var note: String?
}
