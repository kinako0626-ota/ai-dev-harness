#!/usr/bin/env bash
set -euo pipefail

# Update harness templates from latest version
# Usage: ./scripts/update.sh [path/to/ai-dev-harness-repo]

HARNESS_REPO="${1:-}"
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [[ -z "$HARNESS_REPO" ]]; then
  echo "Usage: $0 <path-to-ai-dev-harness-repo>"
  echo ""
  echo "This script re-generates harness files from updated templates."
  echo "Files you have NOT modified will be auto-updated."
  echo "Files you HAVE modified will show a diff for manual resolution."
  exit 1
fi

if [[ ! -f ".harness-version" ]]; then
  error "No .harness-version found. Run init.sh first."
  exit 1
fi

if [[ ! -f "harness.yaml" ]]; then
  error "No harness.yaml found in current directory."
  exit 1
fi

current_version=$(grep "^version:" .harness-version | sed 's/.*: *//')
info "Current harness version: $current_version"

# Re-run init with --force flag but show diffs
info "Re-generating from latest templates..."
"$HARNESS_REPO/init.sh" --force

ok "Update complete. Review changes with: git diff"
