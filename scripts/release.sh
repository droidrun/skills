#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/release.sh <plugin-name> [patch|minor|major]
# Example: ./scripts/release.sh mobilerun patch

PLUGIN="${1:?Usage: $0 <plugin-name> [patch|minor|major]}"
BUMP="${2:-patch}"

if [ ! -f "$PLUGIN/package.json" ]; then
  echo "Error: $PLUGIN/package.json not found"
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "Error: working tree is not clean. Commit or stash changes first."
  exit 1
fi

# Bump version (no git tag — npm workspaces doesn't support it)
cd "$PLUGIN"
NEW_VERSION=$(npm version "$BUMP" --no-git-tag-version | tr -d 'v')
cd ..

# Commit and tag
git add "$PLUGIN/package.json"
git commit -m "$PLUGIN: release v$NEW_VERSION"
git tag "${PLUGIN}/v${NEW_VERSION}"

echo "Released ${PLUGIN}/v${NEW_VERSION}"
echo "Run 'git push --follow-tags' to publish"
