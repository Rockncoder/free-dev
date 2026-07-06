import XCTest
@testable import FreeDev

/// Integration tests that touch live external systems — `xcrun simctl` and the
/// network. They're written to be resilient: if the tool or network is
/// unavailable they assert "didn't crash / returned a sane shape" rather than
/// failing, and skip when there's genuinely nothing to check.
final class LiveServiceTests: XCTestCase {

    // MARK: simctl

    func testRuntimeImagesParseCleanly() {
        // Empty is fine (no downloaded runtimes); any image must be well-formed.
        for image in SimulatorService.runtimeImages() {
            XCTAssertFalse(image.identifier.isEmpty)
            XCTAssertGreaterThanOrEqual(image.sizeBytes, 0)
        }
    }

    func testDevicesParseAndOrphansExist() {
        for device in SimulatorService.allDevices() {
            XCTAssertFalse(device.udid.isEmpty)
        }
        // Orphaned data paths are pre-filtered to existing directories.
        for path in SimulatorService.orphanedDataPaths() {
            XCTAssertTrue(FileManager.default.fileExists(atPath: path),
                          "orphaned path should exist: \(path)")
        }
    }

    func testInstalledRuntimesParse() {
        for runtime in SimulatorService.installediOSRuntimes() {
            XCTAssertFalse(runtime.version.isEmpty)
            XCTAssertFalse(runtime.identifier.isEmpty)
        }
    }

    // MARK: network (Apple gdmf / ipsw.me)

    func testFetchLatestVersionLooksLikeAVersion() async throws {
        guard let info = await VersionService.fetch() else {
            throw XCTSkip("no network and no installed runtime to fall back on")
        }
        XCTAssertFalse(info.source.isEmpty)
        XCTAssertFalse(info.latestVersion.isEmpty)
        // Should begin with a digit and contain only version-ish characters.
        XCTAssertTrue(info.latestVersion.first?.isNumber ?? false,
                      "version should start with a digit: \(info.latestVersion)")
        XCTAssertTrue(info.latestVersion.allSatisfy { $0.isNumber || $0 == "." },
                      "unexpected version format: \(info.latestVersion)")
    }
}
