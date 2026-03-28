#!/usr/bin/env bash
# Minimal YAML parser (bash-only)
# Shared by init.sh and validate-config.sh
#
# Requires CONFIG_FILE to be set before sourcing.

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
