import XCTest
@testable import FreeDev

final class ByteFormatTests: XCTestCase {

    func testZeroAndNegativeRenderAsZeroKB() {
        XCTAssertEqual(ByteFormat.string(0), "0 KB")
        XCTAssertEqual(ByteFormat.string(-5), "0 KB")
    }

    func testGigabyteScale() {
        let s = ByteFormat.string(1_500_000_000)
        XCTAssertFalse(s.isEmpty)
        XCTAssertTrue(s.contains("GB"), "expected a GB-scale string, got \(s)")
    }

    func testMegabyteScale() {
        let s = ByteFormat.string(156_700_000)
        XCTAssertTrue(s.contains("MB"), "expected an MB-scale string, got \(s)")
    }
}
