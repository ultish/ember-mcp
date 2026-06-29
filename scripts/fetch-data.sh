#!/usr/bin/env bash
# Fetches all remote data needed to run ember-mcp in an air-gapped environment.
# Run this on an internet-connected machine before running release.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/../data"
mkdir -p "$DATA_DIR"

echo "==> Fetching Ember documentation (llms-full.txt)..."
curl -fsSL \
  "https://nullvoxpopuli.github.io/ember-ai-information-aggregator/llms-full.txt" \
  -o "$DATA_DIR/llms-full.txt"
echo "    Saved $(du -sh "$DATA_DIR/llms-full.txt" | cut -f1) to data/llms-full.txt"

echo "==> Fetching Ember GitHub releases..."
GITHUB_HEADERS=(-H "Accept: application/vnd.github.v3+json" -H "User-Agent: ember-mcp-server")
if [ -n "${GITHUB_TOKEN:-}" ]; then
  GITHUB_HEADERS+=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi
HTTP_STATUS=$(curl -sL -w "%{http_code}" "${GITHUB_HEADERS[@]}" \
  "https://api.github.com/repos/emberjs/ember.js/releases" \
  -o "$DATA_DIR/ember-releases.json")
if [ "$HTTP_STATUS" = "200" ]; then
  RELEASE_COUNT=$(node -e "console.log(JSON.parse(require('fs').readFileSync('$DATA_DIR/ember-releases.json','utf8')).length)" 2>/dev/null || echo "?")
  echo "    Saved $RELEASE_COUNT releases to data/ember-releases.json"
else
  echo "    Warning: GitHub API returned $HTTP_STATUS (rate limited?). Set GITHUB_TOKEN env var to authenticate."
  echo "    Skipping ember-releases.json — version info will fall back to data in llms-full.txt"
  rm -f "$DATA_DIR/ember-releases.json"
fi

echo "==> Cloning/updating Ember guides source (guides/ only)..."
if [ -d "$DATA_DIR/guides-source/.git" ]; then
  git -C "$DATA_DIR/guides-source" fetch --depth=1 origin
  git -C "$DATA_DIR/guides-source" reset --hard origin/HEAD
else
  git clone --depth=1 --no-checkout --filter=blob:none \
    https://github.com/ember-learn/guides-source.git "$DATA_DIR/guides-source"
  git -C "$DATA_DIR/guides-source" sparse-checkout set guides/
  git -C "$DATA_DIR/guides-source" checkout
fi
GUIDE_COUNT=$(find "$DATA_DIR/guides-source/guides/release" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
echo "    Cloned $GUIDE_COUNT guide pages to data/guides-source"

echo ""
echo "Done. Run scripts/release.sh <tag> to create a GitHub release with these files."
