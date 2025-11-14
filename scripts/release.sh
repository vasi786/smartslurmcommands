#!/usr/bin/env bash
# release.sh — bump version and create a git tag
# Usage:
#   ./scripts/release.sh patch   # 0.1.0 -> 0.1.1
#   ./scripts/release.sh minor   # 0.1.0 -> 0.2.0
#   ./scripts/release.sh major   # 0.1.0 -> 1.0.0

set -euo pipefail

BUMP_TYPE="${1:-}"
if [[ ! "$BUMP_TYPE" =~ ^(major|minor|patch)$ ]]; then
  echo "Usage: $0 {major|minor|patch}" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

VERSION_FILE="$ROOT/VERSION"
if [[ ! -f "$VERSION_FILE" ]]; then
  echo "VERSION file not found at $VERSION_FILE" >&2
  exit 1
fi

old="$(tr -d ' \n' < "$VERSION_FILE")"
IFS=. read -r major minor patch <<<"$old"

case "$BUMP_TYPE" in
  major)
    major=$((major + 1)); minor=0; patch=0;;
  minor)
    minor=$((minor + 1)); patch=0;;
  patch)
    patch=$((patch + 1));;
esac

new="${major}.${minor}.${patch}"

echo "Old version: $old"
echo "New version: $new"

# Write new version
echo "$new" > "$VERSION_FILE"

# Commit + tag (you can remove these if you prefer manual control)
git diff -- "$VERSION_FILE"
read -r -p "Commit and tag v$new? [y/N] " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  git commit -am "Release v$new"
  git tag "v$new"
  echo "Created tag v$new"
  echo "You can now push:"
  echo "  git push origin main --tags"
else
  echo "Not committing/tagging. VERSION changed locally."
fi
