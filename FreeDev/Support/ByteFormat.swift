import Foundation

enum ByteFormat {
    static func string(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 KB" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: bytes)
    }
}

/// Compare two dotted version strings ("26.5.1" vs "26.5") numerically.
enum SemanticVersion {
    static func components(_ raw: String) -> [Int] {
        raw.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 }
    }

    /// Returns true if `lhs` is a higher version than `rhs`.
    static func greater(_ lhs: String, than rhs: String) -> Bool {
        let a = components(lhs)
        let b = components(rhs)
        for i in 0..<max(a.count, b.count) {
            let av = i < a.count ? a[i] : 0
            let bv = i < b.count ? b[i] : 0
            if av != bv { return av > bv }
        }
        return false
    }
}
