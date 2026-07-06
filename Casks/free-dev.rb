cask "free-dev" do
  version "1.0.3"
  sha256 "42bdca029bf3863cd9c1f9ad01f23cf70f3a27e370d1495e6f97ab4ec84f44e7"

  url "https://github.com/Rockncoder/free-dev/releases/download/v#{version}/FreeDev.dmg"
  name "Free Dev"
  desc "Menu bar app that reclaims disk space from Xcode and dev-tool leftovers"
  homepage "https://github.com/Rockncoder/free-dev"

  depends_on macos: :sonoma # macOS 14+ (minimum)

  app "FreeDev.app"

  zap trash: [
    "~/Library/Preferences/com.tekadept.FreeDev.plist",
  ]
end
