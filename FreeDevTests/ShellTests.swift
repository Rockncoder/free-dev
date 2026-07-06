import XCTest
@testable import FreeDev

/// Guards the anti-hang guarantees of `Shell.run`.
final class ShellTests: XCTestCase {

    func testCapturesStdout() {
        let r = Shell.run("/bin/echo", ["hello world"])
        XCTAssertEqual(r.status, 0)
        XCTAssertFalse(r.timedOut)
        XCTAssertEqual(r.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "hello world")
    }

    func testNonZeroExitStatus() {
        let r = Shell.run("/bin/sh", ["-c", "exit 3"])
        XCTAssertEqual(r.status, 3)
        XCTAssertFalse(r.timedOut)
    }

    /// A hanging command must return shortly after its timeout, not run to completion.
    func testTimesOutOnHang() {
        let start = Date()
        let r = Shell.run("/bin/sleep", ["30"], timeout: 1)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertTrue(r.timedOut, "should report a timeout")
        XCTAssertLessThan(elapsed, 6, "must return ~1s (timeout) + grace, not wait 30s")
    }

    /// The exact bug that wedged the scan: the command exits immediately but
    /// leaves a backgrounded child holding the stdout descriptor. With pipe
    /// capture this blocks until the child dies (~30s); with file capture we
    /// return as soon as the command itself exits.
    func testDoesNotHangWhenChildBackgroundsAProcess() {
        let start = Date()
        let r = Shell.run("/bin/sh", ["-c", "sleep 30 & echo started"], timeout: 10)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 6, "should return when the shell exits, not wait for its background child")
        XCTAssertFalse(r.timedOut)
        XCTAssertTrue(r.stdout.contains("started"), "output written before exit should still be captured")
    }
}
