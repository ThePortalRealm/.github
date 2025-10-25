#!/usr/bin/env bash
# ============================================================
#  The Portal Realm --- Repo Secret Sync (single repo)
# ------------------------------------------------------------
#  Usage: bash sync-secrets.sh <org/repo>
#  Pushes selected secrets into the given repository so that
#  every private repo gets the same GH_TOKEN (and others later).
# ============================================================

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: bash sync-secrets.sh <org/repo>"
  exit 1
fi

FULL_REPO="$1"
ORG="${FULL_REPO%%/*}"
REPO="${FULL_REPO##*/}"

# --- secrets to replicate (add more as needed)
SECRETS=("GH_TOKEN")

echo "Syncing secrets for $FULL_REPO"
echo ""

# --- dependency + auth check -----------------------------------------------
for tool in gh jq; do
  if ! command -v "$tool" &>/dev/null; then
    echo "Missing dependency: $tool"
    exit 1
  fi
done

if ! gh auth status &>/dev/null; then
  echo "Not authenticated with gh CLI"
  exit 1
fi

# --- replicate secrets ------------------------------------------------------
for SECRET_NAME in "${SECRETS[@]}"; do
  # Get value from environment (the workflow injects it as $GH_TOKEN)
  VALUE_VAR="${SECRET_NAME}"
  VALUE="${!VALUE_VAR:-}"

  if [[ -z "$VALUE" ]]; then
    echo "- Environment variable $VALUE_VAR not set --- skipping"
    continue
  fi

  echo "- Setting $SECRET_NAME for $FULL_REPO"
  gh secret set "$SECRET_NAME" --body "$VALUE" --repo "$FULL_REPO"
done

echo ""
echo "Finished syncing secrets for $FULL_REPO"
