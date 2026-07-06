import Foundation

/// Helpers for "DeviceSupport"-style folders whose subfolders are named by
/// OS version, e.g. `26.5 (23F77)`. The newest version is always preserved.
enum DeviceSupport {
    /// Names of immediate version subfolders (not full paths).
    static func versionFolders(in directory: String) -> [String] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: directory) else { return [] }
        return entries.filter { name in
            var isDir: ObjCBool = false
            let full = (directory as NSString).appendingPathComponent(name)
            return fm.fileExists(atPath: full, isDirectory: &isDir) && isDir.boolValue
                && !name.hasPrefix(".")
        }
    }

    /// The OS version embedded in a folder name. Handles both the plain
    /// `26.5 (23F77)` form and the device-prefixed `iPhone16,2 26.2.1 (23C71)`
    /// form by picking the whitespace-separated token that is a dotted number.
    static func version(of folderName: String) -> String {
        for token in folderName.split(separator: " ") {
            if token.contains(where: \.isNumber), token.allSatisfy({ $0.isNumber || $0 == "." }) {
                return String(token)
            }
        }
        return String(folderName.split(separator: " ").first ?? "")
    }

    /// The folder with the highest version. `nil` if empty.
    static func newestFolder(in directory: String) -> String? {
        versionFolders(in: directory).max { a, b in
            SemanticVersion.greater(version(of: b), than: version(of: a))
        }
    }

    /// The highest OS version present, `nil` if empty.
    static func maxVersion(in directory: String) -> String? {
        newestFolder(in: directory).map(version(of:))
    }

    /// Folders whose version is strictly OLDER than the newest present.
    /// Folders at the newest version are all kept (e.g. one per device),
    /// so switching devices on the current OS never loses symbols.
    static func staleFolders(in directory: String) -> [String] {
        guard let newest = maxVersion(in: directory) else { return [] }
        return versionFolders(in: directory).filter {
            SemanticVersion.greater(newest, than: version(of: $0))
        }
    }
}
