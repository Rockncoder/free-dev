#!/usr/bin/env bash
#
# metrics.sh — install & traffic metrics for Free Dev, in one command.
#
# Homebrew's public analytics only cover the official homebrew-core/cask, not a
# personal tap — so these GitHub numbers are the real signal. Every
# `brew install` downloads the release DMG, so download_count ≈ installs.
#
# Requires the GitHub CLI (https://cli.github.com), authenticated: `gh auth login`.
#
set -euo pipefail

REPO="Rockncoder/free-dev"
TAP="Rockncoder/homebrew-tap"

command -v gh >/dev/null 2>&1 || { echo "✗ Requires the GitHub CLI: https://cli.github.com"; exit 1; }

echo "📊 Free Dev — metrics"
echo

echo "Release downloads (cumulative; each brew install downloads the DMG):"
printf "  %-10s %-18s %8s\n" "TAG" "ASSET" "DL"
gh api "repos/$REPO/releases" \
  --jq '.[] | .tag_name as $t | (.assets[]? | "\($t)\t\(.name)\t\(.download_count)")' \
  | awk -F'\t' '
      { printf "  %-10s %-18s %8s\n", $1, $2, $3; total += $3 }
      END { print "  ----------------------------------------"
            printf "  %-10s %-18s %8s\n", "", "TOTAL", total+0 }'
echo

echo "Tap traffic (GitHub keeps only a rolling 14-day window; needs push access):"
gh api "repos/$TAP/traffic/clones" --jq '"  clones   \(.count) total / \(.uniques) unique"' 2>/dev/null \
  || echo "  clones   (unavailable)"
gh api "repos/$TAP/traffic/views"  --jq '"  views    \(.count) total / \(.uniques) unique"' 2>/dev/null \
  || echo "  views    (unavailable)"
echo

echo "Tip: Homebrew-core analytics would appear at https://formulae.brew.sh/analytics"
echo "     only if the cask is accepted into the official homebrew-cask repo."
