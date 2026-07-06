import XCTest
@testable import FreeDev

final class CleanerTests: XCTestCase {

    private let home = FileManager.default.homeDirectoryForCurrentUser.path
    private var root: String!   // a sandbox under an allowed root (~/Library/Caches)

    override func setUpWithError() throws {
        root = (home as NSString)
            .appendingPathComponent("Library/Caches/FreeDevUnitTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: root)
    }

    // MARK: isSafePath

    func testIsSafePathAcceptsDeveloperAndCaches() {
        XCTAssertTrue(Cleaner.isSafePath(home + "/Library/Developer/Xcode/DerivedData"))
        XCTAssertTrue(Cleaner.isSafePath(home + "/Library/Caches/com.apple.dt.Xcode"))
        XCTAssertTrue(Cleaner.isSafePath(home + "/.npm/_cacache"))
        XCTAssertTrue(Cleaner.isSafePath(home + "/.pub-cache/hosted"))
    }

    func testIsSafePathRejectsOutsideRoots() {
        XCTAssertFalse(Cleaner.isSafePath("/tmp/whatever"))
        XCTAssertFalse(Cleaner.isSafePath("/etc"))
        XCTAssertFalse(Cleaner.isSafePath(home + "/Documents"))
        XCTAssertFalse(Cleaner.isSafePath(home + "/Library/Application Support"))
    }

    func testIsSafePathRejectsTraversalEscape() {
        // resolves back out of the allowed root -> must be rejected
        XCTAssertFalse(Cleaner.isSafePath(home + "/Library/Caches/../../Documents"))
    }

    // MARK: emptyDirectory

    func testEmptyDirectoryRemovesChildrenButKeepsDirectory() throws {
        let fm = FileManager.default
        try "hello".write(toFile: (root as NSString).appendingPathComponent("a.txt"),
                          atomically: true, encoding: .utf8)
        let sub = (root as NSString).appendingPathComponent("sub")
        try fm.createDirectory(atPath: sub, withIntermediateDirectories: true)
        try "world".write(toFile: (sub as NSString).appendingPathComponent("b.txt"),
                          atomically: true, encoding: .utf8)

        let outcome = Cleaner.perform(.emptyDirectory(path: root))

        XCTAssertTrue(outcome.errors.isEmpty, "unexpected errors: \(outcome.errors)")
        XCTAssertTrue(fm.fileExists(atPath: root), "the directory itself must be kept")
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: root), [], "children must be removed")
    }

    func testEmptyDirectoryRefusesPathOutsideAllowedRoots() throws {
        let fm = FileManager.default
        let unsafeDir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("FreeDevUnsafe-\(UUID().uuidString)")
        try fm.createDirectory(atPath: unsafeDir, withIntermediateDirectories: true)
        let keeper = (unsafeDir as NSString).appendingPathComponent("keep.txt")
        try "x".write(toFile: keeper, atomically: true, encoding: .utf8)
        defer { try? fm.removeItem(atPath: unsafeDir) }

        let outcome = Cleaner.perform(.emptyDirectory(path: unsafeDir))

        XCTAssertEqual(outcome.freedBytes, 0)
        XCTAssertTrue(fm.fileExists(atPath: keeper), "files outside allowed roots must be untouched")
    }

    // MARK: deletePaths

    func testDeletePathsRemovesOnlyListedEntries() throws {
        let fm = FileManager.default
        let a = (root as NSString).appendingPathComponent("a")
        let b = (root as NSString).appendingPathComponent("b")
        try fm.createDirectory(atPath: a, withIntermediateDirectories: true)
        try fm.createDirectory(atPath: b, withIntermediateDirectories: true)

        _ = Cleaner.perform(.deletePaths(paths: [a]))

        XCTAssertFalse(fm.fileExists(atPath: a))
        XCTAssertTrue(fm.fileExists(atPath: b), "unlisted entries must be kept")
    }

    func testDeletePathsSkipsUnsafeEntries() throws {
        let fm = FileManager.default
        let unsafeDir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("FreeDevUnsafe-\(UUID().uuidString)")
        try fm.createDirectory(atPath: unsafeDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(atPath: unsafeDir) }

        let outcome = Cleaner.perform(.deletePaths(paths: [unsafeDir]))

        XCTAssertEqual(outcome.freedBytes, 0)
        XCTAssertTrue(fm.fileExists(atPath: unsafeDir), "paths outside allowed roots must be untouched")
    }

    /// End-to-end: stale device-support folders are pruned while every folder
    /// at the newest version (e.g. one per device) is kept.
    func testStaleDeviceSupportPruneKeepsAllCurrentDevices() throws {
        let fm = FileManager.default
        for name in ["iPad13,8 26.2.1 (23C71)",
                     "iPhone16,2 26.2.1 (23C71)",
                     "iPhone16,2 25.0 (22A1)"] {
            try fm.createDirectory(atPath: (root as NSString).appendingPathComponent(name),
                                   withIntermediateDirectories: true)
        }
        let stale = DeviceSupport.staleFolders(in: root)
        let paths = stale.map { (root as NSString).appendingPathComponent($0) }
        _ = Cleaner.perform(.deletePaths(paths: paths))

        let remaining = Set(try fm.contentsOfDirectory(atPath: root).filter { !$0.hasPrefix(".") })
        XCTAssertEqual(remaining, ["iPad13,8 26.2.1 (23C71)", "iPhone16,2 26.2.1 (23C71)"])
    }
}
