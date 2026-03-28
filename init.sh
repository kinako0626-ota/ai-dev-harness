#!/usr/bin/env bash
set -euo pipefail

# ai-dev-harness init script
# Generates Claude Code configuration files from templates based on harness.yaml
# Usage: ./init.sh [--dry-run] [--force] [--lang ja|en]

VERSION="0.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="harness.yaml"
DRY_RUN=false
FORCE=false
LANG_OVERRIDE=""

# ============================================================
# Argument parsing
# ============================================================
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run) DRY_RUN=true; shift ;;
    --force) FORCE=true; shift ;;
    --lang) LANG_OVERRIDE="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: $0 [--dry-run] [--force] [--lang ja|en]"
      echo ""
      echo "Options:"
      echo "  --dry-run  Preview generated files without writing"
      echo "  --force    Overwrite existing files without confirmation"
      echo "  --lang     Override output language (ja or en)"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ============================================================
# Color output helpers
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ============================================================
# YAML parser (minimal, bash-only)
# ============================================================

# Read a flat YAML value: yaml_get "project.name"
yaml_get() {
  local key="$1"
  local file="${2:-$CONFIG_FILE}"

  # Split key by dots
  IFS='.' read -ra parts <<< "$key"

  if [[ ${#parts[@]} -eq 1 ]]; then
    grep -E "^${parts[0]}:" "$file" 2>/dev/null | head -1 | sed 's/^[^:]*: *//; s/^["'"'"']//; s/["'"'"']$//'
  elif [[ ${#parts[@]} -eq 2 ]]; then
    # Find the section, then the key within it
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

# Read a YAML array: yaml_array "generated_patterns"
yaml_array() {
  local key="$1"
  local file="${2:-$CONFIG_FILE}"

  awk -v key="$key" '
    BEGIN { found = 0; indent = 0 }
    $0 ~ "^" key ":" || $0 ~ "^  " key ":" {
      found = 1
      # Get indent level of the key
      match($0, /^[ ]*/)
      indent = RLENGTH + 2
      next
    }
    found && /^[ ]*- / {
      match($0, /^[ ]*/)
      if (RLENGTH >= indent) {
        val = $0
        sub(/^[ ]*- */, "", val)
        gsub(/^["'"'"']|["'"'"']$/, "", val)
        print val
      } else {
        exit
      }
    }
    found && /^[a-zA-Z]/ { exit }
    found && /^  [a-zA-Z]/ && !/^[ ]*- / {
      match($0, /^[ ]*/)
      if (RLENGTH < indent) exit
    }
  ' "$file"
}

# Read nested YAML array of objects (conventions.mapping)
yaml_convention_mapping() {
  local file="${1:-$CONFIG_FILE}"
  awk '
    BEGIN { in_mapping = 0; in_item = 0; paths = ""; files = "" }
    /^  mapping:/ { in_mapping = 1; next }
    in_mapping && /^  [a-zA-Z]/ { in_mapping = 0 }
    in_mapping && /^    - paths:/ {
      if (paths != "" && files != "") {
        print paths "|" files
      }
      in_item = 1; paths = ""; files = ""; next
    }
    in_mapping && in_item && /^      files:/ { in_item = 2; next }
    in_mapping && in_item == 1 && /^        - / {
      val = $0; sub(/^[ ]*- */, "", val); gsub(/["'"'"']/, "", val)
      if (paths != "") paths = paths ","
      paths = paths val
    }
    in_mapping && in_item == 2 && /^        - / {
      val = $0; sub(/^[ ]*- */, "", val); gsub(/["'"'"']/, "", val)
      if (files != "") files = files ","
      files = files val
    }
    in_mapping && in_item && /^    [a-zA-Z]/ && !/^      / { in_item = 0 }
    END {
      if (paths != "" && files != "") print paths "|" files
    }
  ' "$file"
}

# Check if a YAML boolean value is true
yaml_bool() {
  local val
  val=$(yaml_get "$1")
  [[ "$val" == "true" || "$val" == "yes" || "$val" == "1" ]]
}

# ============================================================
# Validation
# ============================================================
validate_config() {
  local errors=0

  info "Validating $CONFIG_FILE..."

  if [[ ! -f "$CONFIG_FILE" ]]; then
    error "Config file not found: $CONFIG_FILE"
    echo "  Copy harness.yaml.example to harness.yaml and edit it."
    exit 1
  fi

  # Required fields
  local required_fields=(
    "project.name"
    "stack.primary_language"
    "commands.analyze"
    "commands.test"
  )

  for field in "${required_fields[@]}"; do
    local val
    val=$(yaml_get "$field")
    if [[ -z "$val" ]]; then
      error "Required field missing: $field"
      ((errors++))
    fi
  done

  if [[ $errors -gt 0 ]]; then
    error "$errors validation error(s). Fix harness.yaml and retry."
    exit 1
  fi

  ok "Config validation passed"
}

# ============================================================
# Template engine
# ============================================================

# Build sed substitution commands from config
build_substitutions() {
  local project_name analyze_cmd test_cmd build_gen_cmd format_cmd
  local arch_style presentation_layer domain_layer data_layer core_layer
  local source_dir test_dir main_branch task_prefix
  local design_class design_file result_type exception_class
  local mock_lib test_naming_lang test_naming_pattern
  local i18n_accessor reviewer_model analyzer_model planner_model
  local tasks_file progress_file arch_doc master_plan reviews_dir

  project_name=$(yaml_get "project.name")
  # PROJECT_LANG is set in main() as a global variable

  analyze_cmd=$(yaml_get "commands.analyze")
  test_cmd=$(yaml_get "commands.test")
  build_gen_cmd=$(yaml_get "commands.build_generated")
  format_cmd=$(yaml_get "commands.format")

  arch_style=$(yaml_get "architecture.style")
  presentation_layer=$(yaml_get "architecture.layers.presentation")
  domain_layer=$(yaml_get "architecture.layers.domain")
  data_layer=$(yaml_get "architecture.layers.data")
  core_layer=$(yaml_get "architecture.layers.core")

  # Derive source_dir and test_dir from layers
  source_dir="${presentation_layer%%/*}"
  source_dir="${source_dir:-src}"
  test_dir=$(yaml_get "architecture.test_dir")
  test_dir="${test_dir:-test}"

  main_branch=$(yaml_get "git.main_branch")
  main_branch="${main_branch:-main}"

  task_prefix=$(yaml_get "tasks.id_prefix")
  task_prefix="${task_prefix:-TASK}"

  tasks_file=$(yaml_get "tasks.file")
  tasks_file="${tasks_file:-docs/plan/tasks.json}"
  progress_file=$(yaml_get "tasks.progress_file")
  progress_file="${progress_file:-docs/plan/progress.json}"
  arch_doc=$(yaml_get "tasks.architecture_doc")
  arch_doc="${arch_doc:-docs/plan/architecture.md}"
  master_plan=$(yaml_get "tasks.master_plan")
  master_plan="${master_plan:-docs/plan/master_plan.md}"
  reviews_dir="docs/reviews/"

  design_class=$(yaml_get "review.design_system.class_name")
  design_file=$(yaml_get "review.design_system.file")
  result_type=$(yaml_get "review.error_handling.result_type")
  exception_class=$(yaml_get "review.error_handling.exception_class")

  mock_lib=$(yaml_get "review.testing.mock_library")
  mock_lib="${mock_lib:-jest.mock}"
  test_naming_lang=$(yaml_get "review.testing.naming_language")
  test_naming_lang="${test_naming_lang:-en}"
  test_naming_pattern=$(yaml_get "review.testing.naming_pattern")
  test_naming_pattern="${test_naming_pattern:-should do X when Y}"

  i18n_accessor=$(yaml_get "i18n.accessor")

  reviewer_model=$(yaml_get "models.reviewer")
  reviewer_model="${reviewer_model:-sonnet}"
  analyzer_model=$(yaml_get "models.analyzer")
  analyzer_model="${analyzer_model:-sonnet}"
  planner_model=$(yaml_get "models.planner")
  planner_model="${planner_model:-haiku}"

  # Build generated patterns text
  local gen_patterns_text=""
  while IFS= read -r pattern; do
    [[ -z "$pattern" ]] && continue
    if [[ -n "$gen_patterns_text" ]]; then
      gen_patterns_text="$gen_patterns_text, \`$pattern\`"
    else
      gen_patterns_text="\`$pattern\`"
    fi
  done < <(yaml_array "generated_patterns")
  if [[ "$PROJECT_LANG" == "ja" ]]; then
    gen_patterns_text="${gen_patterns_text:-（なし）}"
  else
    gen_patterns_text="${gen_patterns_text:-(none)}"
  fi

  # Build TDD required for text
  local tdd_targets=""
  while IFS= read -r target; do
    [[ -z "$target" ]] && continue
    if [[ -n "$tdd_targets" ]]; then
      tdd_targets="$tdd_targets / $target"
    else
      tdd_targets="$target"
    fi
  done < <(yaml_array "review.testing.tdd_required_for")
  tdd_targets="${tdd_targets:-Service / Repository / UseCase}"

  # Output language
  local output_lang
  if [[ "$PROJECT_LANG" == "ja" ]]; then
    output_lang="日本語"
  else
    output_lang="English"
  fi

  # UI paths and code paths (backtick-separated for markdown output)
  local ui_paths="${presentation_layer}/**"
  local code_paths
  code_paths="${data_layer}/**\`"
  code_paths+=", \`${domain_layer}/**\`"
  code_paths+=", \`${test_dir}/**"

  # Task ID pattern for detection
  local task_id_pattern="${task_prefix}-[0-9]+"

  # Project directory (current working directory)
  local project_dir
  project_dir="$(pwd)"

  # Write sed commands to a temp file
  local sed_file
  sed_file=$(mktemp)

  cat > "$sed_file" << SEDEOF
s|{{PROJECT_NAME}}|${project_name}|g
s|{{PROJECT_LANG}}|${PROJECT_LANG}|g
s|{{OUTPUT_LANGUAGE}}|${output_lang}|g
s|{{ANALYZE_CMD}}|${analyze_cmd}|g
s|{{TEST_CMD}}|${test_cmd}|g
s|{{BUILD_GENERATED_CMD}}|${build_gen_cmd}|g
s|{{FORMAT_CMD}}|${format_cmd}|g
s|{{ARCH_STYLE}}|${arch_style}|g
s|{{PRESENTATION_LAYER}}|${presentation_layer}|g
s|{{DOMAIN_LAYER}}|${domain_layer}|g
s|{{DATA_LAYER}}|${data_layer}|g
s|{{CORE_LAYER}}|${core_layer}|g
s|{{SOURCE_DIR}}|${source_dir}|g
s|{{TEST_DIR}}|${test_dir}|g
s|{{MAIN_BRANCH}}|${main_branch}|g
s|{{TASK_PREFIX}}|${task_prefix}|g
s|{{TASK_ID_PATTERN}}|${task_id_pattern}|g
s|{{TASKS_FILE}}|${tasks_file}|g
s|{{PROGRESS_FILE}}|${progress_file}|g
s|{{ARCHITECTURE_DOC}}|${arch_doc}|g
s|{{MASTER_PLAN_FILE}}|${master_plan}|g
s|{{REVIEWS_DIR}}|${reviews_dir}|g
s|{{DESIGN_SYSTEM_CLASS}}|${design_class}|g
s|{{DESIGN_SYSTEM_FILE}}|${design_file}|g
s|{{RESULT_TYPE}}|${result_type}|g
s|{{EXCEPTION_CLASS}}|${exception_class}|g
s|{{MOCK_LIBRARY}}|${mock_lib}|g
s|{{TEST_NAMING_LANG}}|${test_naming_lang}|g
s|{{TEST_NAMING_PATTERN}}|${test_naming_pattern}|g
s|{{TDD_REQUIRED_FOR}}|${tdd_targets}|g
s|{{I18N_ACCESSOR}}|${i18n_accessor}|g
s|{{REVIEWER_MODEL}}|${reviewer_model}|g
s|{{ANALYZER_MODEL}}|${analyzer_model}|g
s|{{PLANNER_MODEL}}|${planner_model}|g
s|{{GENERATED_PATTERNS}}|${gen_patterns_text}|g
s|{{UI_PATHS}}|${ui_paths}|g
s|{{CODE_PATHS}}|${code_paths}|g
s|{{PROJECT_DIR}}|${project_dir}|g
s|{{CURRENT_DATE}}|$(date +%Y-%m-%d)|g
s|{{CONVENTIONS_DIR}}|docs/conventions/|g
SEDEOF

  echo "$sed_file"
}

# Process conditional blocks: {{#SECTION}}...{{/SECTION}}
process_conditionals() {
  local content="$1"

  # DESIGN_SYSTEM block
  local design_class
  design_class=$(yaml_get "review.design_system.class_name")
  if [[ -z "$design_class" ]]; then
    content=$(echo "$content" | awk '/\{\{#DESIGN_SYSTEM\}\}/{skip=1; next} /\{\{\/DESIGN_SYSTEM\}\}/{skip=0; next} !skip')
  else
    content=$(echo "$content" | sed 's/{{#DESIGN_SYSTEM}}//' | sed 's/{{\/DESIGN_SYSTEM}}//')
  fi

  # RESULT_TYPE block
  local result_type
  result_type=$(yaml_get "review.error_handling.result_type")
  if [[ -z "$result_type" ]]; then
    content=$(echo "$content" | awk '/\{\{#RESULT_TYPE\}\}/{skip=1; next} /\{\{\/RESULT_TYPE\}\}/{skip=0; next} !skip')
  else
    content=$(echo "$content" | sed 's/{{#RESULT_TYPE}}//' | sed 's/{{\/RESULT_TYPE}}//')
  fi

  # I18N_ENABLED block
  if ! yaml_bool "i18n.enabled" 2>/dev/null; then
    content=$(echo "$content" | awk '/\{\{#I18N_ENABLED\}\}/{skip=1; next} /\{\{\/I18N_ENABLED\}\}/{skip=0; next} !skip')
  else
    content=$(echo "$content" | sed 's/{{#I18N_ENABLED}}//' | sed 's/{{\/I18N_ENABLED}}//')
  fi

  # BUILD_GENERATED block
  local build_gen
  build_gen=$(yaml_get "commands.build_generated")
  if [[ -z "$build_gen" ]]; then
    content=$(echo "$content" | awk '/\{\{#BUILD_GENERATED\}\}/{skip=1; next} /\{\{\/BUILD_GENERATED\}\}/{skip=0; next} !skip')
  else
    content=$(echo "$content" | sed 's/{{#BUILD_GENERATED}}//' | sed 's/{{\/BUILD_GENERATED}}//')
  fi

  # TASKS_ENABLED block
  if ! yaml_bool "tasks.enabled" 2>/dev/null; then
    content=$(echo "$content" | awk '/\{\{#TASKS_ENABLED\}\}/{skip=1; next} /\{\{\/TASKS_ENABLED\}\}/{skip=0; next} !skip')
  else
    content=$(echo "$content" | sed 's/{{#TASKS_ENABLED}}//' | sed 's/{{\/TASKS_ENABLED}}//')
  fi

  # ENTITY_REPO_MAPPING block (always remove — project-specific)
  content=$(echo "$content" | awk '/\{\{#ENTITY_REPO_MAPPING\}\}/{skip=1; next} /\{\{\/ENTITY_REPO_MAPPING\}\}/{skip=0; next} !skip')

  # ADDITIONAL_SOURCES block
  local additional
  additional=$(yaml_array "architecture.additional_sources")
  if [[ -z "$additional" ]]; then
    content=$(echo "$content" | awk '/\{\{#ADDITIONAL_SOURCES\}\}/{skip=1; next} /\{\{\/ADDITIONAL_SOURCES\}\}/{skip=0; next} !skip')
  else
    content=$(echo "$content" | sed 's/{{#ADDITIONAL_SOURCES}}//' | sed 's/{{\/ADDITIONAL_SOURCES}}//')
  fi

  echo "$content"
}

# Generate convention mapping table from harness.yaml
generate_convention_mapping() {
  local output=""
  if [[ "$PROJECT_LANG" == "ja" ]]; then
    output+="| 変更対象パス | 参照する規約 |\n"
  else
    output+="| Changed Path | Convention Reference |\n"
  fi
  output+="|---|---|\n"

  while IFS='|' read -r paths files; do
    [[ -z "$paths" ]] && continue
    local path_display file_display
    path_display=$(echo "$paths" | sed 's/,/`, `/g')
    file_display=$(echo "$files" | sed 's/,/`, `/g')
    output+="| \`$path_display\` | \`$file_display\` |\n"
  done < <(yaml_convention_mapping)

  # Global conventions
  local globals
  globals=$(yaml_array "conventions.global")
  if [[ -n "$globals" ]]; then
    local global_display=""
    while IFS= read -r g; do
      [[ -z "$g" ]] && continue
      if [[ -n "$global_display" ]]; then
        global_display="$global_display\`, \`$g"
      else
        global_display="$g"
      fi
    done <<< "$globals"
    if [[ "$PROJECT_LANG" == "ja" ]]; then
      output+="| 共通（常に読む） | \`$global_display\` |\n"
    else
      output+="| Global (always read) | \`$global_display\` |\n"
    fi
  fi

  echo -e "$output"
}

# Process a single template file
process_template() {
  local input="$1"
  local output="$2"
  local sed_file="$3"

  # Read template
  local content
  content=$(cat "$input")

  # Replace {{GENERATED:convention_mapping}} with generated content
  if echo "$content" | grep -q '{{GENERATED:convention_mapping}}'; then
    local mapping
    mapping=$(generate_convention_mapping)
    content=$(echo "$content" | awk -v replacement="$mapping" '{gsub(/\{\{GENERATED:convention_mapping\}\}/, replacement); print}')
  fi

  # Apply conditional blocks
  content=$(process_conditionals "$content")

  # Apply sed substitutions
  content=$(echo "$content" | sed -f "$sed_file")

  if $DRY_RUN; then
    echo -e "${BLUE}--- $output ---${NC}"
    echo "$content" | head -20
    echo "  ... ($(echo "$content" | wc -l | tr -d ' ') lines total)"
    echo ""
  else
    # Check if output file already exists
    if [[ -f "$output" ]] && ! $FORCE; then
      warn "File exists: $output"
      if diff <(echo "$content") "$output" > /dev/null 2>&1; then
        info "  No changes needed, skipping."
        return
      fi
      echo "  Showing diff:"
      diff <(echo "$content") "$output" || true
      read -rp "  Overwrite? [y/N] " answer
      if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
        warn "  Skipped."
        return
      fi
    fi

    mkdir -p "$(dirname "$output")"
    echo "$content" > "$output"
    ok "Generated: $output"
  fi
}

# ============================================================
# Module dependency resolution
# ============================================================
resolve_dependencies() {
  # review_fix requires code_review agents
  if yaml_bool "modules.review_fix" 2>/dev/null; then
    NEED_CODE_REVIEW_AGENTS=true
  fi

  # full_review requires code_review agents
  if yaml_bool "modules.full_review" 2>/dev/null; then
    NEED_CODE_REVIEW_AGENTS=true
  fi

  # implement requires code_review agents (Phase 2)
  if yaml_bool "modules.implement" 2>/dev/null; then
    NEED_CODE_REVIEW_AGENTS=true
  fi

  # implement_team requires code_review agents
  if yaml_bool "modules.implement_team" 2>/dev/null; then
    NEED_CODE_REVIEW_AGENTS=true
  fi
}

# ============================================================
# Main
# ============================================================
main() {
  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║  ai-dev-harness init v${VERSION}             ║"
  echo "╚══════════════════════════════════════════╝"
  echo ""

  validate_config

  # Determine language (PROJECT_LANG is global so other functions can access it)
  PROJECT_LANG="${LANG_OVERRIDE:-$(yaml_get "project.language")}"
  PROJECT_LANG="${PROJECT_LANG:-en}"
  local lang="$PROJECT_LANG"
  local template_dir="${SCRIPT_DIR}/templates/${lang}"

  if [[ ! -d "$template_dir" ]]; then
    warn "Template directory not found for language '$lang', falling back to 'en'"
    lang="en"
    template_dir="${SCRIPT_DIR}/templates/${lang}"
  fi

  if [[ ! -d "$template_dir" ]]; then
    error "Template directory not found: $template_dir"
    exit 1
  fi

  info "Language: $lang"
  info "Templates: $template_dir"
  if $DRY_RUN; then
    warn "DRY RUN mode — no files will be written"
  fi
  echo ""

  # Build substitutions
  local sed_file
  sed_file=$(build_substitutions)
  trap "rm -f '$sed_file'" EXIT

  # Resolve module dependencies
  NEED_CODE_REVIEW_AGENTS=false
  resolve_dependencies

  local generated_count=0

  # ---- Skills ----
  info "=== Skills ==="

  # Shared reference templates (used by implement and full-review)
  local shared_dir="$template_dir/.claude/skills/_shared"

  if yaml_bool "modules.implement" 2>/dev/null; then
    process_template "$template_dir/.claude/skills/implement/SKILL.md.tmpl" ".claude/skills/implement/SKILL.md" "$sed_file"
    process_template "$shared_dir/references/convention-mapping.md.tmpl" ".claude/skills/implement/references/convention-mapping.md" "$sed_file"
    process_template "$shared_dir/references/review-report.md.tmpl" ".claude/skills/implement/references/review-report.md" "$sed_file"
    ((generated_count+=3))
  fi

  if yaml_bool "modules.implement_team" 2>/dev/null; then
    process_template "$template_dir/.claude/skills/implement-team/SKILL.md.tmpl" ".claude/skills/implement-team/SKILL.md" "$sed_file"
    ((generated_count+=1))
  fi

  if yaml_bool "modules.code_review" 2>/dev/null; then
    process_template "$template_dir/.claude/skills/code-review/SKILL.md.tmpl" ".claude/skills/code-review/SKILL.md" "$sed_file"
    ((generated_count+=1))
  fi

  if yaml_bool "modules.review_fix" 2>/dev/null; then
    process_template "$template_dir/.claude/skills/review-fix/SKILL.md.tmpl" ".claude/skills/review-fix/SKILL.md" "$sed_file"
    ((generated_count+=1))
  fi

  if yaml_bool "modules.full_review" 2>/dev/null; then
    process_template "$template_dir/.claude/skills/full-review/SKILL.md.tmpl" ".claude/skills/full-review/SKILL.md" "$sed_file"
    process_template "$template_dir/.claude/skills/full-review/references/agent-prompts.md.tmpl" ".claude/skills/full-review/references/agent-prompts.md" "$sed_file"
    process_template "$template_dir/.claude/skills/full-review/references/fix-mapping.md.tmpl" ".claude/skills/full-review/references/fix-mapping.md" "$sed_file"
    # Shared references (single source of truth in _shared/)
    process_template "$shared_dir/references/convention-mapping.md.tmpl" ".claude/skills/full-review/references/convention-mapping.md" "$sed_file"
    process_template "$shared_dir/references/review-report.md.tmpl" ".claude/skills/full-review/references/review-report.md" "$sed_file"
    ((generated_count+=5))
  fi

  if yaml_bool "modules.plan_status" 2>/dev/null; then
    process_template "$template_dir/.claude/skills/plan-status/SKILL.md.tmpl" ".claude/skills/plan-status/SKILL.md" "$sed_file"
    ((generated_count+=1))
  fi

  if yaml_bool "modules.architecture_check" 2>/dev/null; then
    process_template "$template_dir/.claude/skills/architecture-check/SKILL.md.tmpl" ".claude/skills/architecture-check/SKILL.md" "$sed_file"
    ((generated_count+=1))
  fi

  # Skills README
  if [[ -f "$template_dir/.claude/skills/README.md.tmpl" ]]; then
    process_template "$template_dir/.claude/skills/README.md.tmpl" ".claude/skills/README.md" "$sed_file"
    ((generated_count+=1))
  fi

  # ---- Agents ----
  echo ""
  info "=== Agents ==="

  if [[ "$NEED_CODE_REVIEW_AGENTS" == "true" ]] || yaml_bool "modules.code_review" 2>/dev/null; then
    process_template "$template_dir/.claude/agents/convention-reviewer.md.tmpl" ".claude/agents/convention-reviewer.md" "$sed_file"
    process_template "$template_dir/.claude/agents/quality-reviewer.md.tmpl" ".claude/agents/quality-reviewer.md" "$sed_file"
    process_template "$template_dir/.claude/agents/test-coverage-reviewer.md.tmpl" ".claude/agents/test-coverage-reviewer.md" "$sed_file"
    process_template "$template_dir/.claude/agents/references/calibration-examples.md.tmpl" ".claude/agents/references/calibration-examples.md" "$sed_file"
    ((generated_count+=4))
  fi

  if yaml_bool "modules.architecture_check" 2>/dev/null; then
    process_template "$template_dir/.claude/agents/architecture-analyzer.md.tmpl" ".claude/agents/architecture-analyzer.md" "$sed_file"
    ((generated_count+=1))
  fi

  if yaml_bool "modules.plan_status" 2>/dev/null; then
    process_template "$template_dir/.claude/agents/plan-reader.md.tmpl" ".claude/agents/plan-reader.md" "$sed_file"
    ((generated_count+=1))
  fi

  # ---- Infrastructure ----
  echo ""
  info "=== Infrastructure ==="

  # settings.json
  process_template "$template_dir/.claude/settings.json.tmpl" ".claude/settings.json" "$sed_file"
  ((generated_count+=1))

  # CLAUDE.md
  process_template "$template_dir/CLAUDE.md.tmpl" "CLAUDE.md" "$sed_file"
  ((generated_count+=1))

  # Task tracking files (only create if they don't exist or are empty)
  if yaml_bool "tasks.enabled" 2>/dev/null; then
    local tasks_file_path
    tasks_file_path=$(yaml_get "tasks.file")
    tasks_file_path="${tasks_file_path:-docs/plan/tasks.json}"

    if [[ ! -f "$tasks_file_path" ]] || [[ ! -s "$tasks_file_path" ]]; then
      process_template "$template_dir/docs/plan/tasks.json.tmpl" "$tasks_file_path" "$sed_file"
      ((generated_count+=1))
    else
      info "Skipping $tasks_file_path (already has data)"
    fi

    local progress_path
    progress_path=$(yaml_get "tasks.progress_file")
    progress_path="${progress_path:-docs/plan/progress.json}"

    if [[ ! -f "$progress_path" ]] || [[ ! -s "$progress_path" ]]; then
      process_template "$template_dir/docs/plan/progress.json.tmpl" "$progress_path" "$sed_file"
      ((generated_count+=1))
    else
      info "Skipping $progress_path (already has data)"
    fi
  fi

  # Reviews directory
  mkdir -p "docs/reviews"
  touch "docs/reviews/.gitkeep"

  # ---- Version file ----
  if ! $DRY_RUN; then
    local config_hash
    config_hash=$(md5 -q "$CONFIG_FILE" 2>/dev/null || md5sum "$CONFIG_FILE" 2>/dev/null | cut -d' ' -f1)
    cat > ".harness-version" << EOF
version: $VERSION
generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
config_hash: $config_hash
language: $lang
EOF
    ((generated_count+=1))
  fi

  # ---- Summary ----
  echo ""
  echo "╔══════════════════════════════════════════╗"
  if $DRY_RUN; then
    echo "║  Dry run complete                        ║"
  else
    echo "║  Generation complete!                    ║"
  fi
  echo "╚══════════════════════════════════════════╝"
  echo ""
  ok "Files generated: $generated_count"
  echo ""

  if ! $DRY_RUN; then
    info "Next steps:"
    echo "  1. Review generated files in .claude/"
    echo "  2. Add your convention files to docs/conventions/"
    echo "  3. Add your rules to .claude/rules/"
    echo "  4. Start using: /implement, /code-review, /full-review, etc."
  fi
}

main "$@"
