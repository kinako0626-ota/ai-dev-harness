#!/usr/bin/env bash
set -euo pipefail

# Validate harness.yaml configuration
# Usage: ./scripts/validate-config.sh [path/to/harness.yaml]
#
# Uses the same yaml_get() parser as init.sh to ensure consistent validation.

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

# --- Source shared YAML parser ---
CONFIG_FILE="$CONFIG"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/yaml-parser.sh"

# --- Required fields (same as init.sh validate_config) ---
required_fields=(
  "project.name"
  "stack.primary_language"
  "commands.analyze"
  "commands.test"
)

for field in "${required_fields[@]}"; do
  val=$(yaml_get "$field")
  if [[ -z "$val" ]]; then
    err "Missing required field: $field"
  fi
done

# --- Check version ---
if [[ -z "$(yaml_get "version")" ]]; then
  warn "No version field. Recommended: version: \"1.0\""
fi

# --- Check language ---
lang=$(yaml_get "project.language")
if [[ -n "$lang" ]] && [[ "$lang" != "ja" ]] && [[ "$lang" != "en" ]]; then
  err "Invalid language: $lang (must be 'ja' or 'en')"
fi

# --- Check modules ---
for mod in implement implement_team code_review review_fix full_review plan_status architecture_check; do
  val=$(yaml_get "modules.$mod")
  if [[ -n "$val" ]] && [[ "$val" != "true" ]] && [[ "$val" != "false" ]]; then
    err "modules.${mod} must be true or false, got: $val"
  fi
done

# --- Check models ---
for model_key in reviewer analyzer planner; do
  val=$(yaml_get "models.$model_key")
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
