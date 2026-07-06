import XCTest
@testable import FreeDev

/// Drives the real `AppModel.refresh()` orchestration — a full scan plus the
/// live online iOS-version lookup — and checks the resulting state is coherent.
/// Read-only with respect to the filesystem.
@MainActor
final class AppModelIntegrationTests: XCTestCase {

    func testRefreshPopulatesCoherentState() async {
        let model = AppModel()
        await model.refresh()

        XCTAssertFalse(model.isScanning, "refresh should complete")
        XCTAssertFalse(model.isCleaning)
        XCTAssertFalse(model.items.isEmpty, "catalog should be populated")
        XCTAssertGreaterThan(model.freeBytes, 0, "free disk space should be measured")

        // Totals are internally consistent.
        XCTAssertGreaterThanOrEqual(model.totalReclaimable, model.selectedReclaimable)
        XCTAssertGreaterThanOrEqual(model.selectedReclaimable, 0)
        XCTAssertEqual(model.selectedCount,
                       model.items.filter { $0.selected && $0.exists }.count)

        // Visible groups: ordered subset of known groups, all items present.
        for group in model.visibleGroups {
            XCTAssertTrue(AppModel.groupOrder.contains(group.name))
            XCTAssertFalse(group.items.isEmpty, "empty groups must be hidden")
            XCTAssertTrue(group.items.allSatisfy(\.exists), "hidden items must not appear in a group")
        }
        // Group order is preserved.
        let names = model.visibleGroups.map(\.name)
        XCTAssertEqual(names, AppModel.groupOrder.filter(names.contains))
    }

    func testToggleFlipsSelectionAndCount() async throws {
        let model = AppModel()
        await model.refresh()

        guard let item = model.items.first(where: { $0.exists }) else {
            throw XCTSkip("no reclaimable items on this machine to toggle")
        }
        let wasSelected = item.selected
        let countBefore = model.selectedCount

        model.toggle(item)

        let now = model.items.first { $0.id == item.id }!.selected
        XCTAssertNotEqual(now, wasSelected, "toggle should flip selection")
        XCTAssertEqual(model.selectedCount, countBefore + (now ? 1 : -1))
    }
}
