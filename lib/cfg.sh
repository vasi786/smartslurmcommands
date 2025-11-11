#!/usr/bin/env bash
# shellcheck shell=bash

# cfg.sh - Cfg library module
# Global assoc map
declare -A __CFG

# Parse simple KEY=VALUE lines (no spaces around =). Ignore blanks and # comments.
cfg::parse_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    # trim
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    # expect KEY=VALUE
    [[ "$line" =~ ^([A-Za-z0-9_]+)=(.*)$ ]] || continue
    local k="${BASH_REMATCH[1]}"
    local v="${BASH_REMATCH[2]}"
    # strip surrounding quotes if present
    [[ "$v" =~ ^\".*\"$ ]] && v="${v:1:${#v}-2}"
    __CFG["$k"]="$v"
  done < "$file"
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
  # Env overrides: SSC_FOO=value -> FOO=value
  local k
  while IFS='=' read -r k v; do
    k="${k#SSC_}"
    __CFG["$k"]="$v"
  done < <(env | grep -E '^SSC_[A-Za-z0-9_]+=' || true)
}

# Get with optional default
cfg::get() {
  local key="$1" def="${2:-}"
  [[ -n "${__CFG[$key]+x}" ]] && printf '%s\n' "${__CFG[$key]}" || printf '%s\n' "$def"
}

