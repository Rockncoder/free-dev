# Distributing Free Dev (notarized + Homebrew)

Free Dev ships **outside the Mac App Store** as a Developer ID–signed, notarized
app. That keeps every feature (including `simctl` runtime cleanup, which the App
Store sandbox forbids) and lets users install with a double-click or `brew`.

## Prerequisites (one-time)

1. **Apple Developer Program** membership ($99/yr).
2. **Developer ID Application** certificate — Xcode → Settings → Accounts →
   Manage Certificates → `+` → *Developer ID Application*.
3. A **notary credential** stored in your keychain:
   ```
   xcrun notarytool store-credentials free-dev-notary \
     --apple-id "you@example.com" --team-id "ABCDE12345" \
     --password "xxxx-xxxx-xxxx-xxxx"   # app-specific password from appleid.apple.com
   ```
4. Your **Team ID**: `export DEVELOPMENT_TEAM=ABCDE12345`
   (developer.apple.com → Account → Membership).

## Cut a release

```bash
export DEVELOPMENT_TEAM=ABCDE12345
./notarize.sh              # → notarized, stapled FreeDev.dmg  (+ prints version & sha256)
```

Then publish it and update the cask:

```bash
gh release create v1.0.0 FreeDev.dmg -t "Free Dev 1.0" --notes "First release"
# copy the version + sha256 the script printed into Casks/free-dev.rb
```

Sanity-check the signature before shipping:

```bash
spctl -a -vvv -t install /path/to/FreeDev.app   # should say: accepted, source=Notarized Developer ID
```

## Homebrew install

The cask lives in `Casks/free-dev.rb`. To let people `brew install` it, publish a
personal **tap** (a repo named `homebrew-tap`):

```bash
# one-time: create the tap repo and add the cask
gh repo create Rockncoder/homebrew-tap --public -d "Homebrew tap"
mkdir -p homebrew-tap/Casks && cp Casks/free-dev.rb homebrew-tap/Casks/
# commit & push that repo…
```

Users then install with:

```bash
brew install --cask rockncoder/tap/free-dev
```

(Or, before a tap exists, test locally: `brew install --cask ./Casks/free-dev.rb`.)

## Updating

For each new version: bump `MARKETING_VERSION` in the project, run `./notarize.sh`,
`gh release create vX.Y.Z FreeDev.dmg`, then update `version` + `sha256` in the
cask and push the tap. Homebrew handles upgrades from there.
