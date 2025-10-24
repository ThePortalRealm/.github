#!/usr/bin/env bash
# ============================================================
#  Sync .github templates and community files to all enabled repos
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_DIR="$ROOT_DIR"
REPOS_FILE="$SCRIPT_DIR/repos.json"

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

echo "Syncing .github templates and policies..."
echo ""

# --- Load repos.json
repos=$(jq -c '.repos[] | select(.enabled == true)' "$REPOS_FILE")

while IFS= read -r repo; do
  ORG=$(echo "$repo" | jq -r '.org')
  NAME=$(echo "$repo" | jq -r '.name')
  FULL="$ORG/$NAME"
  echo "Syncing $FULL"

  TMPDIR=$(mktemp -d)
  gh repo clone "$FULL" "$TMPDIR" -- -q --depth=1
  cd "$TMPDIR"

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
    git add .github >/dev/null
    git commit -m "Sync .github templates and community files" >/dev/null
    git push origin HEAD >/dev/null
    echo "Updated $FULL"
  else
    echo "No changes in $FULL"
  fi

  cd "$SCRIPT_DIR"
  rm -rf "$TMPDIR"
  echo ""
done <<< "$repos"

echo "All enabled repositories synced successfully!"
