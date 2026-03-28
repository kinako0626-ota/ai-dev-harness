#!/usr/bin/env bash
set -euo pipefail

# Validate harness.yaml configuration
# Usage: ./scripts/validate-config.sh [path/to/harness.yaml]
#
# Uses the same yaml_get() parser as init.sh to ensure consistent validation.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_DIR="$(dirname "$SCRIPT_DIR")"
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

# --- Reuse yaml_get from init.sh ---
CONFIG_FILE="$CONFIG"

yaml_get() {
  local key="$1"
  local file="${2:-$CONFIG_FILE}"
  IFS='.' read -ra parts <<< "$key"

  if [[ ${#parts[@]} -eq 1 ]]; then
    grep -E "^${parts[0]}:" "$file" 2>/dev/null | head -1 | sed 's/^[^:]*: *//; s/^["'"'"']//; s/["'"'"']$//'
  elif [[ ${#parts[@]} -eq 2 ]]; then
    awk -v section="${parts[0]}" -v key="${parts[1]}" '
      /^[a-zA-Z]/ { current_section = $0; gsub(/:.*/, "", current_section) }
      current_section == section && $0 ~ "^  " key ":" {
        val = $0
        sub(/^[^:]*: */, "", val)
        gsub(/^["'"'"']|["'"'"']$/, "", val)
        print val
        exit
      }
    ' "$file"
  elif [[ ${#parts[@]} -eq 3 ]]; then
    awk -v s1="${parts[0]}" -v s2="${parts[1]}" -v key="${parts[2]}" '
      /^[a-zA-Z]/ { l1 = $0; gsub(/:.*/, "", l1); l2 = "" }
      /^  [a-zA-Z]/ && l1 == s1 { l2 = $0; gsub(/^ */, "", l2); gsub(/:.*/, "", l2) }
      l1 == s1 && l2 == s2 && $0 ~ "^    " key ":" {
        val = $0
        sub(/^[^:]*: */, "", val)
        gsub(/^["'"'"']|["'"'"']$/, "", val)
        print val
        exit
      }
    ' "$file"
  fi
}

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
