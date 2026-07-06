import XCTest
@testable import FreeDev

final class DeviceSupportTests: XCTestCase {

    private var dir: String!

    override func setUpWithError() throws {
        dir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("FreeDevDS-\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for name in ["17.0 (19A1)", "26.5 (23F77)", "26.5.1 (23F79)", ".hidden"] {
            try FileManager.default.createDirectory(
                atPath: (dir as NSString).appendingPathComponent(name),
                withIntermediateDirectories: true)
        }
        // a stray file (not a directory) should be ignored by versionFolders
        try "x".write(toFile: (dir as NSString).appendingPathComponent("note.txt"),
                      atomically: true, encoding: .utf8)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: dir)
    }

    func testVersionOf() {
        XCTAssertEqual(DeviceSupport.version(of: "26.5 (23F77)"), "26.5")
        XCTAssertEqual(DeviceSupport.version(of: "26.5.1 (23F79)"), "26.5.1")
    }

    func testVersionOfHandlesDevicePrefix() {
        // real-world naming: "<device> <version> (<build>)"
        XCTAssertEqual(DeviceSupport.version(of: "iPhone16,2 26.2.1 (23C71)"), "26.2.1")
        XCTAssertEqual(DeviceSupport.version(of: "iPad13,8 26.2.1 (23C71)"), "26.2.1")
    }

    func testStaleFoldersKeepsAllAtNewestVersion() throws {
        let d = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("FreeDevDS2-\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: d, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: d) }
        for name in ["iPad13,8 26.2.1 (23C71)", "iPhone16,2 26.2.1 (23C71)", "iPhone16,2 25.0 (22A1)"] {
            try FileManager.default.createDirectory(
                atPath: (d as NSString).appendingPathComponent(name), withIntermediateDirectories: true)
        }
        // only the 25.0 folder is stale; both 26.2.1 device folders are kept
        XCTAssertEqual(DeviceSupport.staleFolders(in: d), ["iPhone16,2 25.0 (22A1)"])
    }

    func testStaleFoldersEmptyWhenAllSameVersion() throws {
        let d = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("FreeDevDS3-\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: d, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: d) }
        for name in ["iPad13,8 26.2.1 (23C71)", "iPhone16,2 26.2.1 (23C71)"] {
            try FileManager.default.createDirectory(
                atPath: (d as NSString).appendingPathComponent(name), withIntermediateDirectories: true)
        }
        XCTAssertEqual(DeviceSupport.staleFolders(in: d), [], "nothing is stale when every device is on the current OS")
    }

    func testVersionFoldersExcludesHiddenAndFiles() {
        let folders = DeviceSupport.versionFolders(in: dir).sorted()
        XCTAssertEqual(folders, ["17.0 (19A1)", "26.5 (23F77)", "26.5.1 (23F79)"])
        XCTAssertFalse(folders.contains(".hidden"))
        XCTAssertFalse(folders.contains("note.txt"))
    }

    func testNewestFolderPicksHighestVersion() {
        XCTAssertEqual(DeviceSupport.newestFolder(in: dir), "26.5.1 (23F79)")
    }

    func testNewestFolderEmptyDirectoryIsNil() throws {
        let empty = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("FreeDevEmpty-\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: empty, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: empty) }
        XCTAssertNil(DeviceSupport.newestFolder(in: empty))
    }
}
