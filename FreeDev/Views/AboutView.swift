import SwiftUI

/// Small "About" card shown from the popover footer — who made it, version, links.
struct AboutView: View {
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 12) {
            Image("MenuBarIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 46, height: 46)
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 2) {
                Text("Free Dev").font(.system(size: 16, weight: .semibold))
                Text("Version \(AboutView.appVersion)")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }

            Text("Reclaims disk space from Xcode, the iOS Simulator, and dev-tool leftovers — safely.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Divider().padding(.horizontal, 16)

            VStack(spacing: 6) {
                Text("Created by **Troy Miles**")
                    .font(.system(size: 12))
                HStack(spacing: 14) {
                    Link("Source", destination: URL(string: "https://github.com/Rockncoder/free-dev")!)
                    Link("@Rockncoder", destination: URL(string: "https://github.com/Rockncoder")!)
                }
                .font(.system(size: 11))
            }

            Text("© 2026 Troy Miles · MIT License")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .frame(width: 260)
    }
}
