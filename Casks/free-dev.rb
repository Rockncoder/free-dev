cask "free-dev" do
  version "1.0.2"
  sha256 "30c1c7cd4b0309b9d460eb8b15abc70f8673831609d1e332311b7b88d2e02247"

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
