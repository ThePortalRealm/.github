#!/usr/bin/env bash
# ============================================================
#  Sync .github templates and community files for a single repo
#  Usage: bash sync-files.sh <org/repo>
# ============================================================

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: bash sync-files.sh <org/repo>"
  exit 1
fi

FULL="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_DIR="$ROOT_DIR"

TMPDIR=$(mktemp -d)
cleanup() {
  cd "$SCRIPT_DIR" || true
  rm -rf "$TMPDIR" || true
}
trap cleanup EXIT

# --- Dependency check
for cmd in gh git jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing dependency: $cmd"
    exit 1
  fi
done

# --- Verify source folders
if [ ! -d "$SOURCE_DIR/.github/ISSUE_TEMPLATE" ]; then
  echo "Missing .github/ISSUE_TEMPLATE folder"
  exit 1
fi

echo "Syncing .github templates and policies for $FULL"
echo ""

# --- Clone repo quietly
if ! gh repo clone "$FULL" "$TMPDIR" -- --depth=1 >/dev/null 2>&1; then
  echo "Failed to clone $FULL"
  exit 1
fi
cd "$TMPDIR"

# Disable CRLF warnings on Windows
git config core.autocrlf false
git config core.safecrlf false

mkdir -p .github

FILES=(
  "$SOURCE_DIR/.github/ISSUE_TEMPLATE"
  "$SOURCE_DIR/.github/PULL_REQUEST_TEMPLATE"
  "$SOURCE_DIR/CONTRIBUTING.md"
  "$SOURCE_DIR/SECURITY.md"
  "$SOURCE_DIR/CODE_OF_CONDUCT.md"
)

for f in "${FILES[@]}"; do
  [ -e "$f" ] && cp -r "$f" .github/
done

if [ -n "$(git status --porcelain)" ]; then
  echo "Committing changes..."
  git add .github
  git commit -m "Sync .github templates and community files" || true
  echo "Pushing changes..."
  if ! git push origin HEAD; then
    echo " Push failed for $FULL"
  else
    echo "Updated $FULL"
  fi
else
  echo "No changes in $FULL"
fi
