#!/usr/bin/env bash

# cfg.sh - Cfg library module
# Global assoc map
declare -A __CFG

cfg::is_known_key() {
  case "$1" in
    confirm|dry_run|smartcancel.include_dependents) return 0 ;;
    *) return 1 ;;
  esac
}

cfg::warn() {
  printf 'warning: config: %s\n' "$*" >&2
}

# Parse simple KEY=VALUE lines (no spaces around =). Ignore blanks and # comments.
cfg::parse_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  local line_no=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line_no=$((line_no + 1))
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    if [[ "$line" != *=* ]]; then
      cfg::warn "$file:$line_no: ignored malformed line"
      continue
    fi

    local k="${line%%=*}"
    local v="${line#*=}"
    k="${k#"${k%%[![:space:]]*}"}"
    k="${k%"${k##*[![:space:]]}"}"
    v="${v#"${v%%[![:space:]]*}"}"
    v="${v%"${v##*[![:space:]]}"}"

    if [[ ! "$k" =~ ^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$ ]]; then
      cfg::warn "$file:$line_no: ignored malformed key '$k'"
      continue
    fi
    if ! cfg::is_known_key "$k"; then
      cfg::warn "$file:$line_no: ignored unknown key '$k'"
      continue
    fi

    if [[ "$v" == \"* || "$v" == \'* ]]; then
      local first="${v:0:1}" last="${v: -1}"
      if [[ ${#v} -lt 2 || "$first" != "$last" ]]; then
        cfg::warn "$file:$line_no: ignored unterminated quoted value for '$k'"
        continue
      fi
      v="${v:1:${#v}-2}"
    fi
    __CFG["$k"]="$v"
  done < "$file"
  return 0
}

# Load with precedence: env > user > project > built-in
cfg::load() {
  local home_cfg="${XDG_CONFIG_HOME:-$HOME/.config}/smartslurmcommands/config"
  local proj_cfg="$PWD/.smartslurmcommands"
  local built_in="$SSC_HOME/etc/smartslurmcommands.conf"

  # Start from built-in defaults
  cfg::parse_file "$built_in"
  # Project override (optional)
  cfg::parse_file "$proj_cfg"
  # User override
  cfg::parse_file "$home_cfg"
  # Explicit environment mappings avoid ambiguous underscore/dot conversion.
  [[ -n "${SSC_CONFIRM+x}" ]] && __CFG[confirm]="$SSC_CONFIRM"
  [[ -n "${SSC_DRY_RUN+x}" ]] && __CFG[dry_run]="$SSC_DRY_RUN"
  [[ -n "${SSC_SMARTCANCEL_INCLUDE_DEPENDENTS+x}" ]] \
    && __CFG[smartcancel.include_dependents]="$SSC_SMARTCANCEL_INCLUDE_DEPENDENTS"
  return 0
}

# Get with optional default
cfg::get() {
  local key="$1" def="${2:-}"
  [[ -n "${__CFG[$key]+x}" ]] && printf '%s\n' "${__CFG[$key]}" || printf '%s\n' "$def"
}

cfg::get_bool() {
  local key="$1" def="${2:-false}" value
  value="$(cfg::get "$key" "$def")"
  case "${value,,}" in
    true|yes|1|on) printf 'true\n' ;;
    false|no|0|off) printf 'false\n' ;;
    *) die 2 "Invalid boolean value for '$key': $value" ;;
  esac
}
