#!/usr/bin/env bash
# release.sh — bump version and create a git tag
# Usage:
#   ./scripts/release.sh patch       # 0.1.4 -> 0.1.5
#   ./scripts/release.sh minor       # 0.1.4 -> 0.2.0
#   ./scripts/release.sh major       # 0.1.4 -> 1.0.0
#   ./scripts/release.sh 1.0.0       # 0.1.4 -> 1.0.0 (explicit)

set -euo pipefail

TARGET="${1:-}"

if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 {major|minor|patch|X.Y.Z}" >&2
  exit 2
fi

MODE=""
BUMP_TYPE=""
EXPLICIT_VERSION=""

if [[ "$TARGET" =~ ^(major|minor|patch)$ ]]; then
  MODE="bump"
  BUMP_TYPE="$TARGET"
elif [[ "$TARGET" =~ ^[0-9]+(\.[0-9]+){2}$ ]]; then
  MODE="explicit"
  EXPLICIT_VERSION="$TARGET"
else
  echo "Usage: $0 {major|minor|patch|X.Y.Z}" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

VERSION_FILE="$ROOT/VERSION"
if [[ ! -f "$VERSION_FILE" ]]; then
  echo "VERSION file not found at $VERSION_FILE" >&2
  exit 1
fi

old="$(tr -d ' \n' < "$VERSION_FILE")"

if [[ ! "$old" =~ ^[0-9]+(\.[0-9]+){2}$ ]]; then
  echo "VERSION file does not contain a valid X.Y.Z version: '$old'" >&2
  exit 1
fi

IFS=. read -r major minor patch <<<"$old"

case "$MODE" in
  bump)
    case "$BUMP_TYPE" in
      major)
        major=$((major + 1)); minor=0; patch=0;;
      minor)
        minor=$((minor + 1)); patch=0;;
      patch)
        patch=$((patch + 1));;
    esac
    new="${major}.${minor}.${patch}"
    ;;
  explicit)
    new="$EXPLICIT_VERSION"
    if [[ "$new" == "$old" ]]; then
      echo "VERSION is already $new; nothing to do."
      exit 0
    fi
    ;;
esac

echo "Old version: $old"
echo "New version: $new"

# Write new version
echo "$new" > "$VERSION_FILE"

# Show what changed
git diff -- "$VERSION_FILE"

read -r -p "Commit and tag v$new? [y/N] " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  git commit -am "Release v$new"
  git tag "v$new"
  echo "Created tag v$new"

  read -r -p "Push tag v$new to origin? [y/N] " push_ans
  if [[ "$push_ans" =~ ^[Yy]$ ]]; then
    git push origin "v$new"
    echo "Pushed tag v$new to origin"
  else
    echo "Not pushing tag. You can push later with:"
    echo "  git push origin v$new"
  fi
else
  echo "Not committing/tagging. VERSION changed locally."
fi
