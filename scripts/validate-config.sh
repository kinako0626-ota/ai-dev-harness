#!/usr/bin/env bash
set -euo pipefail

# Validate harness.yaml configuration
# Usage: ./scripts/validate-config.sh [path/to/harness.yaml]

CONFIG="${1:-harness.yaml}"
ERRORS=0
WARNINGS=0

RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

err()  { echo -e "${RED}[ERROR]${NC} $1"; ((ERRORS++)); }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; ((WARNINGS++)); }
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }

if [[ ! -f "$CONFIG" ]]; then
  err "Config file not found: $CONFIG"
  exit 1
fi

echo "Validating: $CONFIG"
echo ""

# Required fields
for field in "project:" "  name:" "stack:" "  primary_language:" "commands:" "  analyze:" "  test:"; do
  if ! grep -q "^${field}" "$CONFIG" 2>/dev/null && ! grep -q "^  ${field}" "$CONFIG" 2>/dev/null; then
    err "Missing required field: $field"
  fi
done

# Check version
if ! grep -q "^version:" "$CONFIG"; then
  warn "No version field. Recommended: version: \"1.0\""
fi

# Check language
lang=$(grep "^  language:" "$CONFIG" 2>/dev/null | head -1 | sed 's/.*: *//' | tr -d '"'"'" || true)
if [[ -n "$lang" ]] && [[ "$lang" != "ja" ]] && [[ "$lang" != "en" ]]; then
  err "Invalid language: $lang (must be 'ja' or 'en')"
fi

# Check modules
for mod in implement implement_team code_review review_fix full_review plan_status architecture_check; do
  val=$(grep "  ${mod}:" "$CONFIG" 2>/dev/null | head -1 | sed 's/.*: *//' || true)
  if [[ -n "$val" ]] && [[ "$val" != "true" ]] && [[ "$val" != "false" ]]; then
    err "modules.${mod} must be true or false, got: $val"
  fi
done

# Check models
for model_key in reviewer analyzer planner; do
  val=$(grep "  ${model_key}:" "$CONFIG" 2>/dev/null | head -1 | sed 's/.*: *//' | tr -d '"'"'" || true)
  if [[ -n "$val" ]] && [[ "$val" != "sonnet" ]] && [[ "$val" != "opus" ]] && [[ "$val" != "haiku" ]]; then
    warn "models.${model_key}: '$val' — expected sonnet, opus, or haiku"
  fi
done

echo ""
if [[ $ERRORS -eq 0 ]]; then
  ok "Validation passed ($WARNINGS warning(s))"
else
  err "Validation failed: $ERRORS error(s), $WARNINGS warning(s)"
  exit 1
fi
