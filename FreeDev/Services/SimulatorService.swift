import Foundation

/// Reads simulator state via `simctl`. Only ever *deletes* devices that the
/// system itself reports as unavailable (their runtime is gone).
enum SimulatorService {
    struct Device {
        let udid: String
        let name: String
        let isAvailable: Bool
        let dataPath: String?
    }

    struct Runtime {
        let name: String
        let version: String
        let identifier: String
        let isAvailable: Bool
    }

    /// A downloaded simulator runtime *image* on disk (from `simctl runtime list`),
    /// which is distinct from an installed/usable runtime.
    struct RuntimeImage {
        let identifier: String
        let platform: String
        let version: String
        let sizeBytes: Int64
        let deletable: Bool
    }

    // MARK: JSON shapes

    private struct DeviceList: Decodable {
        let devices: [String: [RawDevice]]
    }
    private struct RawDevice: Decodable {
        let udid: String
        let name: String
        let isAvailable: Bool?
        let availabilityError: String?
        let dataPath: String?
    }
    private struct RuntimeList: Decodable {
        let runtimes: [RawRuntime]
    }
    private struct RawRuntime: Decodable {
        let name: String
        let version: String
        let identifier: String
        let isAvailable: Bool?
        let platform: String?
    }
    private struct RawRuntimeImage: Decodable {
        let version: String?
        let platformIdentifier: String?
        let sizeBytes: Int64?
        let deletable: Bool?
    }

    // MARK: Queries

    static func allDevices() -> [Device] {
        let result = Shell.run("/usr/bin/xcrun", ["simctl", "list", "-j", "devices"], timeout: 20)
        guard let data = result.stdout.data(using: .utf8),
              let list = try? JSONDecoder().decode(DeviceList.self, from: data) else {
            return []
        }
        return list.devices.values.flatMap { $0 }.map {
            Device(
                udid: $0.udid,
                name: $0.name,
                isAvailable: $0.isAvailable ?? ($0.availabilityError == nil),
                dataPath: $0.dataPath
            )
        }
    }

    /// Data directories belonging to orphaned (unavailable) devices — used to
    /// estimate how much `delete unavailable` will actually reclaim.
    static func orphanedDataPaths() -> [String] {
        allDevices()
            .filter { !$0.isAvailable }
            .compactMap { $0.dataPath }
            .filter { FileManager.default.fileExists(atPath: $0) }
    }

    static func installediOSRuntimes() -> [Runtime] {
        let result = Shell.run("/usr/bin/xcrun", ["simctl", "list", "-j", "runtimes"], timeout: 20)
        guard let data = result.stdout.data(using: .utf8),
              let list = try? JSONDecoder().decode(RuntimeList.self, from: data) else {
            return []
        }
        return list.runtimes
            .filter { ($0.platform ?? "").localizedCaseInsensitiveContains("ios")
                        || $0.name.localizedCaseInsensitiveContains("iOS") }
            .map { Runtime(name: $0.name, version: $0.version, identifier: $0.identifier,
                           isAvailable: $0.isAvailable ?? true) }
    }

    /// Downloaded runtime images on disk, with their sizes.
    static func runtimeImages() -> [RuntimeImage] {
        let result = Shell.run("/usr/bin/xcrun", ["simctl", "runtime", "list", "-j"], timeout: 20)
        guard let data = result.stdout.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: RawRuntimeImage].self, from: data) else {
            return []
        }
        return dict.map { key, value in
            RuntimeImage(
                identifier: key,
                platform: value.platformIdentifier ?? "",
                version: value.version ?? "0",
                sizeBytes: value.sizeBytes ?? 0,
                deletable: value.deletable ?? false
            )
        }
    }

    // MARK: Actions

    @discardableResult
    static func deleteOrphaned() -> Bool {
        Shell.run("/usr/bin/xcrun", ["simctl", "delete", "unavailable"]).status == 0
    }

    @discardableResult
    static func deleteRuntime(_ identifier: String) -> Bool {
        Shell.run("/usr/bin/xcrun", ["simctl", "runtime", "delete", identifier]).status == 0
    }
}
