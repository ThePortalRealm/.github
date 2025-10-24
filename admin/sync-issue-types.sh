#!/bin/bash
# ============================================================
#  The Portal Realm --- Org Issue Type Sync Utility
#  Creates or updates org-level issue types via GraphQL API
#  Requires: gh CLI (authenticated with full repo/org scope)
#  Supports /* ... */ and // ... comments in JSON files
# ============================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TYPES_FILE="$SCRIPT_DIR/issue-types.json"
REPOS_FILE="$SCRIPT_DIR/repos.json"

# --- dependency check --------------------------------------------------------
for tool in gh jq perl; do
  if ! command -v "$tool" &>/dev/null; then
    echo "Missing dependency: $tool"
    exit 1
  fi
done

# --- strip_comments() --------------------------------------------------------
strip_comments() {
  # Remove multi-line /* ... */ and // ... comments, plus trailing commas
  perl -0777 -pe '
    s{/\*.*?\*/}{}gs;          # remove all /* ... */ blocks
    s{//[^\n]*}{}g;            # remove // line comments
    s/,\s*([}\]])/\1/g;        # remove trailing commas before ] or }
  ' "$1"
}

# --- prepare cleaned JSON copies --------------------------------------------
for f in "$TYPES_FILE" "$REPOS_FILE"; do
  [ -f "$f" ] || { echo "Missing file: $f"; exit 1; }
done

CLEAN_TYPES=$(mktemp)
CLEAN_REPOS=$(mktemp)
strip_comments "$TYPES_FILE" > "$CLEAN_TYPES"
strip_comments "$REPOS_FILE" > "$CLEAN_REPOS"

# --- extract org from repos.json --------------------------------------------
ORG=$(jq -r '[.repos[] | select(.enabled == true)][0].org // .repos[0].org' "$CLEAN_REPOS")
if [[ -z "$ORG" || "$ORG" == "null" ]]; then
  echo "Could not determine organization from repos.json"
  exit 1
fi

# --- retrieve organization ID -----------------------------------------------
ORG_ID=$(gh api graphql -f query="
{
  organization(login: \"$ORG\") {
    id
  }
}" --jq '.data.organization.id')

if [[ -z "$ORG_ID" ]]; then
  echo "Could not retrieve organization ID for $ORG"
  exit 1
fi

TYPE_COUNT=$(jq '. | length' "$CLEAN_TYPES")
echo " Syncing $TYPE_COUNT issue types for organization: $ORG"
echo

# --- fetch existing types ---------------------------------------------------
EXISTING_JSON=$(gh api graphql -f query="
{
  organization(login: \"$ORG\") {
    issueTypes(first: 100) {
      nodes { id name color description }
    }
  }
}" --jq '.data.organization.issueTypes.nodes')

# --- iterate new definitions ------------------------------------------------
jq -c '.[]' "$CLEAN_TYPES" | while read -r t; do
  NAME=$(echo "$t" | jq -r '.name')
  COLOR_HEX=$(echo "$t" | jq -r '.color')
  DESC=$(echo "$t" | jq -r '.description')

  # --- convert hex color to IssueTypeColor enum -----------------------------
  case "$COLOR_HEX" in
    000000|1B1F23) COLOR="BLACK" ;;
    0366D6|1F6FEB) COLOR="BLUE" ;;
    2E8B57|22863A|0E8A16) COLOR="GREEN" ;;
    D73A4A|CB2431) COLOR="RED" ;;
    EAC54F|FBCA04) COLOR="YELLOW" ;;
    9370DB|6F42C1) COLOR="PURPLE" ;;
    708090|586069) COLOR="GRAY" ;;
    FFA500|D18616) COLOR="ORANGE" ;;
    *) COLOR="GRAY" ;;
  esac

  EXISTING_ID=$(echo "$EXISTING_JSON" | jq -r --arg NAME "$NAME" '.[] | select(.name==$NAME) | .id')

  if [[ -n "$EXISTING_ID" && "$EXISTING_ID" != "null" ]]; then
    echo "Updating: $NAME ($COLOR)"
    gh api graphql -f query="
    mutation {
      updateIssueType(input: {
        issueTypeId: \"$EXISTING_ID\",
        color: $COLOR,
        description: \"$DESC\"
      }) {
        issueType { id name color description }
      }
    }" >/dev/null
  else
    echo "Creating: $NAME ($COLOR)"
    gh api graphql -f query="
    mutation {
      createIssueType(input: {
        ownerId: \"$ORG_ID\",
        name: \"$NAME\",
        description: \"$DESC\",
        color: $COLOR,
        isEnabled: true
      }) {
        issueType { id name color description isEnabled }
      }
    }" >/dev/null
  fi
done

echo
echo "All issue types synced successfully for $ORG!"
