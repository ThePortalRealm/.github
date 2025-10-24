#!/usr/bin/env bash
# ============================================================
#  The Portal Realm --- Unified GitHub Sync Controller (bash)
# ------------------------------------------------------------
#  Runs label, issue type, and .github file sync operations
#  for all enabled repositories.
#  Guarantees working directory is restored on exit.
# ============================================================

set -euo pipefail

FILES=false
ISSUES=false
LABELS=false

# --- Parse flags
for arg in "$@"; do
  case "$arg" in
    --files)  FILES=true ;;
    --issues) ISSUES=true ;;
    --labels) LABELS=true ;;
  esac
done

START_DIR="$(pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOS_FILE="$SCRIPT_DIR/repos.json"

# --- Verify repos.json
if [ ! -f "$REPOS_FILE" ]; then
  echo "Missing repos.json"
  exit 1
fi

echo "=== The Portal Realm GitHub Sync ==="
echo ""

# --- Read enabled repos
repos=$(jq -c '.repos[] | select(.enabled == true)' "$REPOS_FILE")

while IFS= read -r repo; do
  ORG=$(echo "$repo" | jq -r '.org')
  NAME=$(echo "$repo" | jq -r '.name')
  FULL="$ORG/$NAME"
  echo "-> Processing $FULL"
  echo ""

  if $FILES; then
    echo "[1/3] Syncing templates and policies..."
    bash "$SCRIPT_DIR/sync-files.sh" "$FULL"
    echo ""
  fi

  if $ISSUES; then
    echo "[2/3] Syncing issue types..."
    bash "$SCRIPT_DIR/sync-issue-types.sh" "$FULL"
    echo ""
  fi

  if $LABELS; then
    echo "[3/3] Syncing labels..."
    bash "$SCRIPT_DIR/sync-labels.sh" "$FULL"
    echo ""
  fi

  echo "Done: $FULL"
  echo "--------------------------------------"
  echo ""
done <<< "$repos"

cd "$START_DIR"
echo "All enabled repositories processed successfully!"
