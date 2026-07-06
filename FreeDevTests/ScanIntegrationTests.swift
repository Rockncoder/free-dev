import XCTest
@testable import FreeDev

/// Exercises the real `DiskScanner` against this machine — running actual `du`
/// and `xcrun simctl` — and validates the shape of the catalog it produces.
/// Read-only: nothing here deletes anything.
final class ScanIntegrationTests: XCTestCase {

    private let home = FileManager.default.homeDirectoryForCurrentUser.path

    func testScanProducesWellFormedCatalog() async {
        let items = await DiskScanner.scan(home: home)

        XCTAssertFalse(items.isEmpty, "scan should always return the full catalog")

        // ids are unique
        let ids = items.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "item ids must be unique")

        let validGroups = Set(AppModel.groupOrder)
        for item in items {
            XCTAssertFalse(item.id.isEmpty, "every item needs an id")
            XCTAssertFalse(item.title.isEmpty, "\(item.id) has no title")
            XCTAssertTrue(validGroups.contains(item.group), "\(item.id) has unknown group '\(item.group)'")
            XCTAssertGreaterThanOrEqual(item.reclaimableBytes, 0, "\(item.id) has negative size")

            // Safety invariants that must always hold:
            if item.safety == .caution {
                XCTAssertFalse(item.selected, "caution item \(item.id) must never be pre-selected")
            }
            if item.selected {
                XCTAssertTrue(item.exists, "selected item \(item.id) must exist")
            }
            if !item.exists {
                XCTAssertFalse(item.selected, "hidden item \(item.id) must not be selected")
                XCTAssertEqual(item.reclaimableBytes, 0, "hidden item \(item.id) should report 0")
            }
        }
    }

    func testScanContainsCoreCategories() async {
        let ids = Set(await DiskScanner.scan(home: home).map(\.id))
        let core: Set<String> = [
            "derived-data", "xcode-caches", "swiftpm-caches",
            "sim-caches", "orphaned-sims", "old-runtimes",
            "homebrew", "npm", "pub-cache",
        ]
        XCTAssertTrue(ids.isSuperset(of: core),
                      "missing categories: \(core.subtracting(ids).sorted())")
    }

    func testScanOrderingIsStable() async {
        let first = await DiskScanner.scan(home: home).map(\.id)
        let second = await DiskScanner.scan(home: home).map(\.id)
        XCTAssertEqual(first, second, "catalog ordering should be deterministic")
    }
}
