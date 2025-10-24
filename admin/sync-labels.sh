#!/usr/bin/env bash
# ============================================================
#  The Portal Realm --- Label Sync Utility (single repo)
#  Usage: bash sync-labels.sh <org/repo> [--clean]
# ============================================================

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: bash sync-labels.sh <org/repo> [--clean]"
  exit 1
fi

FULL_REPO="$1"
CLEAN_FLAG="${2:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABELS_FILE="$SCRIPT_DIR/labels.json"

# --- dependency check ---------------------------------------------------------
for tool in gh jq grep perl; do
  if ! command -v "$tool" &>/dev/null; then
    echo "Missing dependency: $tool"
    exit 1
  fi
done

# --- strip comments from JSON -------------------------------------------------
strip_comments() {
  perl -0777 -pe '
    s{/\*.*?\*/}{}gs;          # remove /* ... */ blocks
    s{//[^\n]*}{}g;            # remove // comments
    s/,\s*([}\]])/\1/g;        # remove trailing commas
  ' "$1"
}

CLEAN_LABELS=$(mktemp)
strip_comments "$LABELS_FILE" > "$CLEAN_LABELS"

# --- verify file -------------------------------------------------------------
[ -f "$CLEAN_LABELS" ] || { echo "Missing file: $CLEAN_LABELS"; exit 1; }

LABEL_COUNT=$(jq '. | length' "$CLEAN_LABELS")
echo "Syncing $LABEL_COUNT labels for $FULL_REPO"
echo ""

# --- ensure repo accessible ---------------------------------------------------
if ! gh repo view "$FULL_REPO" &>/dev/null; then
  echo "Cannot access $FULL_REPO"
  exit 1
fi

# --- sync labels -------------------------------------------------------------
jq -c '.[]' "$CLEAN_LABELS" | while read -r label; do
  name=$(echo "$label" | jq -r '.name')
  color=$(echo "$label" | jq -r '.color')
  desc=$(echo "$label" | jq -r '.description')

  if gh label view "$name" --repo "$FULL_REPO" &>/dev/null; then
    echo "- Updating: $name"
    gh label edit "$name" --repo "$FULL_REPO" --color "$color" --description "$desc" --force >/dev/null
  else
    echo "- Creating: $name"
    gh label create "$name" --repo "$FULL_REPO" --color "$color" --description "$desc" --force >/dev/null
  fi
done

echo "Finished syncing labels for $FULL_REPO"
echo ""

# --- optional cleanup --------------------------------------------------------
if [[ "$CLEAN_FLAG" == "--clean" ]]; then
  echo "Cleaning labels not in labels.json for $FULL_REPO..."
  EXISTING=$(gh label list --repo "$FULL_REPO" --json name -q '.[].name')
  DEFINED=$(jq -r '.[].name' "$CLEAN_LABELS")

  for label in $EXISTING; do
    if ! grep -qx "$label" <<< "$DEFINED"; then
      echo "- Removing: $label"
      gh label delete "$label" --repo "$FULL_REPO" --yes >/dev/null || true
    fi
  done
fi

echo ""
echo "Label sync complete for $FULL_REPO"
