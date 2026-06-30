#!/usr/bin/env bash
# Creates a GitHub release for the given tag and uploads data/ as a tarball asset.
# Usage: ./scripts/release.sh <tag>  (e.g. ./scripts/release.sh v0.2.0)
# Requires: gh CLI authenticated (run `gh auth login` first)
# Run scripts/fetch-data.sh first to populate data/

set -euo pipefail

TAG="${1:-}"
if [ -z "$TAG" ]; then
  echo "Usage: $0 <tag>  (e.g. $0 v0.2.0)"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
DATA_DIR="$ROOT_DIR/data"
ASSET="$ROOT_DIR/ember-mcp-data.tar.gz"

# Sanity check
if [ ! -f "$DATA_DIR/llms-full.txt" ]; then
  echo "Error: data/llms-full.txt not found. Run scripts/fetch-data.sh first."
  exit 1
fi

# Clean up any previous failed attempt for this tag
if gh release view "$TAG" &>/dev/null; then
  echo "==> Found existing release $TAG — deleting it to retry..."
  gh release delete "$TAG" --yes --cleanup-tag
  git tag -d "$TAG" 2>/dev/null || true
fi

echo "==> Creating data archive..."
tar -czf "$ASSET" -C "$ROOT_DIR" data/
echo "    $(du -sh "$ASSET" | cut -f1) -> ember-mcp-data.tar.gz"

# Create the release (gh creates the tag on remote automatically).
# Tag is only created locally after a successful release so there are no orphaned tags.
echo "==> Creating GitHub release $TAG..."
if gh release create "$TAG" \
  --title "ember-mcp $TAG" \
  --notes "## Installation

\`\`\`
npm install ember-mcp
\`\`\`

## Air-gap installation

1. Download \`ember-mcp-data.tar.gz\` from this release
2. Extract it next to the package: \`tar -xzf ember-mcp-data.tar.gz\`
3. \`npm install && node index.js\`

The \`data/\` directory contains a bundled snapshot of Ember docs, guides, and release info so the server runs with no internet access." \
  "$ASSET"; then
  git tag "$TAG"
  echo ""
  REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
  echo "Released: https://github.com/$REPO/releases/tag/$TAG"
else
  echo ""
  echo "Release failed. No tag was created locally. Fix the issue and re-run."
fi

rm -f "$ASSET"
