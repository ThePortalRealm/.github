#!/bin/bash
# ============================================================
#  The Portal Realm — Label Sync Utility
#  Supports JSON comments and multi-org repo structure.
#  Safe for public repos — no secrets stored.
# ============================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABELS_FILE="$SCRIPT_DIR/labels.json"
REPOS_FILE="$SCRIPT_DIR/repos.json"

# --- dependency check ---------------------------------------------------------
for tool in gh jq grep; do
  if ! command -v "$tool" &>/dev/null; then
    echo "Missing dependency: $tool"
    exit 1
  fi
done

# --- strip comments from JSON -------------------------------------------------
strip_comments() {
  # Remove multi-line /* ... */ and // ... comments, plus clean up trailing commas
  perl -0777 -pe '
    s{/\*.*?\*/}{}gs;          # remove all /* ... */ blocks (multi-line safe)
    s{//[^\n]*}{}g;            # remove // line comments
    s/,\s*([}\]])/\1/g;        # remove trailing commas before ] or }
  ' "$1"
}

CLEAN_LABELS=$(mktemp)
CLEAN_REPOS=$(mktemp)
strip_comments "$LABELS_FILE" > "$CLEAN_LABELS"
strip_comments "$REPOS_FILE" > "$CLEAN_REPOS"

# --- verify files -------------------------------------------------------------
for f in "$CLEAN_LABELS" "$CLEAN_REPOS"; do
  [ -f "$f" ] || { echo "Missing file: $f"; exit 1; }
done

# --- summary -----------------------------------------------------------------
LABEL_COUNT=$(jq '. | length' "$CLEAN_LABELS")
REPO_COUNT=$(jq '[.repos[] | select(.enabled == true)] | length' "$CLEAN_REPOS")
echo " Syncing $LABEL_COUNT labels across $REPO_COUNT repositories"
echo

# --- iterate enabled repos ---------------------------------------------------
jq -c '.repos[] | select(.enabled == true)' "$CLEAN_REPOS" | while read -r repo; do
  ORG=$(echo "$repo" | jq -r '.org')
  REPO_NAME=$(echo "$repo" | jq -r '.name')
  FULL_REPO="$ORG/$REPO_NAME"

  echo "Syncing labels for $FULL_REPO"

  if ! gh repo view "$FULL_REPO" &>/dev/null; then
    echo " Skipping: cannot access $FULL_REPO"
    echo
    continue
  fi

  jq -c '.[]' "$CLEAN_LABELS" | while read -r label; do
    name=$(echo "$label" | jq -r '.name')
    color=$(echo "$label" | jq -r '.color')
    desc=$(echo "$label" | jq -r '.description')

    if gh label view "$name" --repo "$FULL_REPO" &>/dev/null; then
      echo "  Updating: $name"
      gh label edit "$name" --repo "$FULL_REPO" --color "$color" --description "$desc" --force >/dev/null
    else
      echo "  Creating: $name"
      gh label create "$name" --repo "$FULL_REPO" --color "$color" --description "$desc" --force >/dev/null
    fi
  done

  echo "Finished syncing $FULL_REPO"

  # Optional cleanup step
  if [[ "${1:-}" == "--clean" ]]; then
    echo "Cleaning labels not in labels.json for $FULL_REPO..."
    # Get all existing label names from the repo
    EXISTING=$(gh label list --repo "$FULL_REPO" --json name -q '.[].name')
    # Get all label names from the JSON
    DEFINED=$(jq -r '.[].name' "$CLEAN_LABELS")

    # Loop through each existing label and delete if not in DEFINED
    for label in $EXISTING; do
      if ! grep -qx "$label" <<< "$DEFINED"; then
        echo "  Removing: $label"
        gh label delete "$label" --repo "$FULL_REPO" --yes >/dev/null || true
      fi
    done
  fi

  echo
done

echo "All enabled repositories synced successfully!"
