cask "free-dev" do
  version "1.0.0"
  sha256 "REPLACE_AFTER_NOTARIZE" # shasum -a 256 FreeDev.dmg (printed by ./notarize.sh)

  url "https://github.com/Rockncoder/free-dev/releases/download/v#{version}/FreeDev.dmg",
      verified: "github.com/Rockncoder/free-dev/"
  name "Free Dev"
  desc "Menu bar app that reclaims disk space from Xcode and dev-tool leftovers"
  homepage "https://github.com/Rockncoder/free-dev"

  depends_on macos: ">= :sonoma" # macOS 14+

  app "FreeDev.app"

  zap trash: [
    "~/Library/Preferences/com.tekadept.FreeDev.plist",
  ]
end
