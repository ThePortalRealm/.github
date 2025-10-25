#!/usr/bin/env bash
# ============================================================
#  The Portal Realm --- .github Template Sync (bash)
# ------------------------------------------------------------
#  Syncs .github templates and community files for one repo.
#  Usage: bash sync-files.sh <org/repo>
#  Markdown-safe output (no colors, emojis, or special chars)
# ============================================================

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: bash sync-files.sh <org/repo>"
  exit 1
fi

FULL_REPO="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_DIR="$ROOT_DIR"

TMPDIR=$(mktemp -d)
cleanup() {
  cd "$SCRIPT_DIR" || true
  rm -rf "$TMPDIR" || true
}
trap cleanup EXIT

# --- Dependency check --------------------------------------------------------
for cmd in gh git jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing dependency: $cmd"
    exit 1
  fi
done

# --- Verify source folders ---------------------------------------------------
if [ ! -d "$SOURCE_DIR/.github/ISSUE_TEMPLATE" ]; then
  echo "Missing .github/ISSUE_TEMPLATE folder"
  exit 1
fi

echo "Syncing .github templates and policies for $FULL_REPO"
echo ""

# --- Clone repo --------------------------------------------------------------
if ! gh repo clone "$FULL_REPO" "$TMPDIR" -- --depth=1 >/dev/null 2>&1; then
  echo "Failed to clone $FULL_REPO"
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

# --- Cleanup: remove stale files only from managed directories ---------------
echo "- Checking for stale files in ISSUE_TEMPLATE and PULL_REQUEST_TEMPLATE"

MANAGED_DIRS=(
  ".github/ISSUE_TEMPLATE"
  ".github/PULL_REQUEST_TEMPLATE"
)

for dir in "${MANAGED_DIRS[@]}"; do
  if [ -d "$dir" ]; then
    echo "  Checking $dir ..."
    SRC_PATH="$SOURCE_DIR/$dir"

    # Build relative file lists
    SOURCE_FILES=$(cd "$SOURCE_DIR" && find "$dir" -type f | sort)
    TARGET_FILES=$(find "$dir" -type f | sort)

    # Find files that exist in target but not in source
    STALE_FILES=$(comm -23 <(echo "$TARGET_FILES") <(echo "$SOURCE_FILES"))

    if [[ -z "$STALE_FILES" ]]; then
      echo "  - No stale files in $dir"
    else
      echo "$STALE_FILES" | while read -r FILE; do
        [[ -z "$FILE" ]] && continue
        echo "  - Removing stale file: $FILE"
        rm -f "$FILE"
      done
    fi
  fi
done

# --- Commit and push if needed -----------------------------------------------
if [ -n "$(git status --porcelain)" ]; then
  echo "- Committing changes"
  git add .github
  git commit -m "Sync .github templates and community files" >/dev/null || true
  echo "- Pushing changes"
  if git push origin HEAD >/dev/null 2>&1; then
    echo "- Updated $FULL_REPO"
  else
    echo "! Push failed for $FULL_REPO"
  fi
else
  echo "No changes detected in $FULL_REPO"
fi

echo ""
echo "Completed .github sync for $FULL_REPO"
