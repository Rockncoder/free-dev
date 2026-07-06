import XCTest
@testable import FreeDev

final class SemanticVersionTests: XCTestCase {

    func testGreaterByPatch() {
        XCTAssertTrue(SemanticVersion.greater("26.5.1", than: "26.5"))
        XCTAssertFalse(SemanticVersion.greater("26.5", than: "26.5.1"))
    }

    func testEqualIsNotGreater() {
        XCTAssertFalse(SemanticVersion.greater("26.5", than: "26.5"))
        // trailing .0 is numerically equal to the shorter form
        XCTAssertFalse(SemanticVersion.greater("26.5.0", than: "26.5"))
        XCTAssertFalse(SemanticVersion.greater("26.5", than: "26.5.0"))
    }

    func testMajorMinorDominates() {
        XCTAssertTrue(SemanticVersion.greater("17.0", than: "9.6.4"))
        XCTAssertFalse(SemanticVersion.greater("9.6.4", than: "17.7.11"))
    }

    func testNumericNotLexical() {
        // lexical string comparison would wrongly say "26.10" < "26.9"
        XCTAssertTrue(SemanticVersion.greater("26.10", than: "26.9"))
        XCTAssertTrue(SemanticVersion.greater("26.5.11", than: "26.5.2"))
    }

    func testComponentsParsing() {
        XCTAssertEqual(SemanticVersion.components("26.5.1"), [26, 5, 1])
        XCTAssertEqual(SemanticVersion.components("26"), [26])
        // stray non-digits inside a component are stripped, not fatal
        XCTAssertEqual(SemanticVersion.components("23F77"), [2377])
    }
}
