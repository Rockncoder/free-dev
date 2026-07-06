import XCTest
@testable import FreeDev

/// End-to-end reclaim: writes real files into an isolated directory under an
/// allowed root (`~/Library/Caches/…`), then drives the real `Cleaner` +
/// `DiskSpace` (`du`) and verifies bytes are actually freed. The directory is
/// unique per run and removed in tearDown, so real caches are never touched.
final class CleanerIntegrationTests: XCTestCase {

    private let home = FileManager.default.homeDirectoryForCurrentUser.path
    private var root: String!

    override func setUpWithError() throws {
        root = (home as NSString)
            .appendingPathComponent("Library/Caches/FreeDevIntegration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: root)
    }

    /// ~1.2 MB across a couple files and a subdirectory.
    private func seedPayload() throws {
        let fm = FileManager.default
        let chunk = Data(repeating: 0xAB, count: 400_000)
        try chunk.write(to: URL(fileURLWithPath: (root as NSString).appendingPathComponent("a.bin")))
        let sub = (root as NSString).appendingPathComponent("sub")
        try fm.createDirectory(atPath: sub, withIntermediateDirectories: true)
        try chunk.write(to: URL(fileURLWithPath: (sub as NSString).appendingPathComponent("b.bin")))
        try chunk.write(to: URL(fileURLWithPath: (sub as NSString).appendingPathComponent("c.bin")))
    }

    func testEmptyDirectoryReclaimsRealBytesAndKeepsFolder() throws {
        try seedPayload()

        let before = DiskSpace.sizeOnDisk(root)
        XCTAssertGreaterThan(before, 1_000_000, "seed should be measurable on disk")

        let outcome = Cleaner.perform(.emptyDirectory(path: root))

        XCTAssertTrue(outcome.errors.isEmpty, "unexpected errors: \(outcome.errors)")
        XCTAssertGreaterThan(outcome.freedBytes, 900_000, "should reclaim roughly the payload")
        XCTAssertTrue(FileManager.default.fileExists(atPath: root), "the directory itself must remain")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root), [], "children must be gone")
        XCTAssertLessThan(DiskSpace.sizeOnDisk(root), before, "measured size must drop")
    }

    func testDeletePathsReclaimsRealBytesForListedEntriesOnly() throws {
        let fm = FileManager.default
        let chunk = Data(repeating: 0xCD, count: 500_000)
        let doomed = (root as NSString).appendingPathComponent("old")
        let kept = (root as NSString).appendingPathComponent("current")
        try fm.createDirectory(atPath: doomed, withIntermediateDirectories: true)
        try fm.createDirectory(atPath: kept, withIntermediateDirectories: true)
        try chunk.write(to: URL(fileURLWithPath: (doomed as NSString).appendingPathComponent("x.bin")))
        try chunk.write(to: URL(fileURLWithPath: (kept as NSString).appendingPathComponent("y.bin")))

        let outcome = Cleaner.perform(.deletePaths(paths: [doomed]))

        XCTAssertGreaterThan(outcome.freedBytes, 400_000)
        XCTAssertFalse(fm.fileExists(atPath: doomed))
        XCTAssertTrue(fm.fileExists(atPath: kept), "unlisted entries must be untouched")
    }
}
