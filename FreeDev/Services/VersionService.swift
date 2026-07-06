import Foundation

/// Looks up the current public iOS version online, and reports which iOS
/// simulator runtimes are installed locally.
///
/// Primary source: Apple's own public metadata feed at
/// `https://gdmf.apple.com/v2/pmv` (used by MDM to learn released versions).
/// Fallback: the community `ipsw.me` API.
enum VersionService {
    struct Info {
        let latestVersion: String
        let latestBuild: String?
        let source: String
        let installedRuntimes: [String]
    }

    static func fetch() async -> Info? {
        let installed = SimulatorService.installediOSRuntimes()
            .map { $0.version }
            .sorted { SemanticVersion.greater($0, than: $1) }

        if let apple = try? await fetchFromApple() {
            return Info(latestVersion: apple.version, latestBuild: apple.build,
                        source: "apple.com", installedRuntimes: installed)
        }
        if let ipsw = try? await fetchFromIPSW() {
            return Info(latestVersion: ipsw.version, latestBuild: ipsw.build,
                        source: "ipsw.me", installedRuntimes: installed)
        }
        return installed.first.map {
            Info(latestVersion: $0, latestBuild: nil, source: "installed", installedRuntimes: installed)
        }
    }

    // MARK: Apple gdmf feed

    private struct GDMF: Decodable {
        let PublicAssetSets: AssetSets?
        struct AssetSets: Decodable { let iOS: [Asset]? }
        struct Asset: Decodable {
            let ProductVersion: String
            let Build: String?
            let SupportedDevices: [String]?
        }
    }

    private static func fetchFromApple() async throws -> (version: String, build: String?) {
        let url = URL(string: "https://gdmf.apple.com/v2/pmv")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("FreeDev/1.0", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        let feed = try JSONDecoder().decode(GDMF.self, from: data)

        // The "iOS" array mixes iPhone/iPad/watch entries — keep only ones that
        // support an iPhone, then take the highest ProductVersion.
        let iphoneAssets = (feed.PublicAssetSets?.iOS ?? []).filter { asset in
            (asset.SupportedDevices ?? []).contains { $0.hasPrefix("iPhone") }
        }
        guard let newest = iphoneAssets.max(by: {
            SemanticVersion.greater($1.ProductVersion, than: $0.ProductVersion)
        }) else {
            throw URLError(.cannotParseResponse)
        }
        return (newest.ProductVersion, newest.Build)
    }

    // MARK: ipsw.me fallback

    private struct IPSWDevice: Decodable {
        let firmwares: [Firmware]
        struct Firmware: Decodable { let version: String; let buildid: String? }
    }

    private static func fetchFromIPSW() async throws -> (version: String, build: String?) {
        // A recent iPhone; firmwares are returned newest-first.
        let url = URL(string: "https://api.ipsw.me/v4/device/iPhone16,1?type=ipsw")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        let (data, _) = try await URLSession.shared.data(for: request)
        let device = try JSONDecoder().decode(IPSWDevice.self, from: data)
        guard let newest = device.firmwares.max(by: {
            SemanticVersion.greater($1.version, than: $0.version)
        }) else {
            throw URLError(.cannotParseResponse)
        }
        return (newest.version, newest.buildid)
    }
}
