#!/usr/bin/env bash
# ============================================================
#  The Portal Realm --- Unified GitHub Sync Controller (bash)
# ------------------------------------------------------------
#  Runs file, issue type, and label syncs for all enabled repos.
#  Always runs all three operations and restores working directory.
#  Clean Markdown-safe output for GitHub workflow summaries.
# ============================================================

set -euo pipefail

START_DIR="$(pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOS_FILE="$SCRIPT_DIR/repos.json"

# --- Verify repos.json --------------------------------------------------------
if [ ! -f "$REPOS_FILE" ]; then
  echo "Missing repos.json"
  exit 1
fi

echo "# The Portal Realm GitHub Sync"
echo ""

# --- Read enabled repos -------------------------------------------------------
repos=$(jq -c '.repos[] | select(.enabled == true)' "$REPOS_FILE")

while IFS= read -r repo; do
  ORG=$(echo "$repo" | jq -r '.org')
  NAME=$(echo "$repo" | jq -r '.name')
  FULL="$ORG/$NAME"

  echo "## Repository: $FULL"
  echo ""

  echo "### [1/3] Templates and Policies"
  bash "$SCRIPT_DIR/sync-files.sh" "$FULL" || {
    echo "sync-files.sh failed for $FULL"
    exit 1
  }
  echo ""
  echo "---"
  echo ""

  echo "### [2/3] Issue Types"
  bash "$SCRIPT_DIR/sync-issue-types.sh" "$FULL" || {
    echo "sync-issue-types.sh failed for $FULL"
    exit 1
  }
  echo ""
  echo "---"
  echo ""

  echo "### [3/3] Labels"
  bash "$SCRIPT_DIR/sync-labels.sh" "$FULL" || {
    echo "sync-labels.sh failed for $FULL"
    exit 1
  }
  echo ""
  echo "---"
  echo ""

  echo "Done: $FULL"
  echo ""
done <<< "$repos"

cd "$START_DIR"
echo "All enabled repositories processed successfully."
