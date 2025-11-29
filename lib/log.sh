#!/usr/bin/env bash
# shellcheck shell=bash

# Logging level: none, info, debug
: "${SSC_LOG_LEVEL:=none}"

# --- Colors (good contrast on black background) ---
LOG_RED=$'\e[31m'
LOG_CYAN=$'\e[36m'
LOG_YELLOW=$'\e[0;33m'
LOG_REAL_YELLOW=$'\e[1;33m'
LOG_BLUE=$'\e[1;34m'
LOG_RESET=$'\e[0m'

# ---- Log functions ----
log_error() {
  printf '%sERROR:%s %s%s\n' "$LOG_RED" "$LOG_REAL_YELLOW" "$*" "$LOG_RESET" >&2
}

log_debug_prefix() {
  printf '%sDEBUG:%s' "$LOG_BLUE" "$LOG_REAL_YELLOW"
}

log_info_prefix() {
  printf '%sINFO:%s' "$LOG_CYAN" "$LOG_YELLOW"
}

log_debug() { log_debug_prefix; printf " %s\n" "$*"; }
log_info()  { log_info_prefix;  printf " %s\n" "$*"; }
log_warn()  { log_warn_prefix;  printf " %s\n" "$*"; }


log_jobs_count() {
  local label="$1"
  local text="$2"
  local level="${SSC_LOG_LEVEL:-none}"

  # Only run in info/debug
  [[ "$level" == "info" || "$level" == "debug" ]] || return 0

  # Count non-empty lines
  local n
  n="$(printf '%s\n' "$text" | sed '/^$/d' | wc -l)"
  # Info line
  log_info_prefix >&2
  printf ' %s: %s job(s) found\n' "$label" "$n" >&2

  # If not debug → done
  [[ "$level" == "debug" ]] || return 0
  # Debug header
  log_debug_prefix >&2
  printf ' %s output (begin)\n' "$label" >&2
  # Print each line in debug color format
  while IFS='' read -r line; do
    printf '%bDEBUG:%b | %s%b\n' \
      "$LOG_BLUE" "$LOG_REAL_YELLOW" "$line" "$LOG_RESET" >&2
  done <<< "$text"
  # Debug footer
  log_debug_prefix >&2
  printf ' %s output (end)\n' "$label" >&2
}



# Generic helper:
#   out="$(log_run_capture "label" cmd arg1 arg2 ...)"
log_run_capture() {
  local label="$1"; shift
  local cmd="$1"; shift

  local level="${SSC_LOG_LEVEL:-none}"

  # Debug: show full command invocation
  if [[ "$level" == "debug" ]]; then
    local IFS=' '
    log_debug_prefix >&2
    printf ' %s: %s %s\n' "$label" "$cmd" "$*" >&2
  fi

  # Run the command and capture output
  local out
  if ! out="$("$cmd" "$@")"; then
    local rc=$?
    log_error "$label: $cmd failed with exit code $rc"
    return "$rc"
  fi

  # Info/debug → print number of output lines
  if [[ "$level" == "info" || "$level" == "debug" ]]; then
    local n
    n="$(printf '%s\n' "$out" | sed '/^$/d' | wc -l)"
    log_info_prefix >&2
    printf ' %s: %s job(s) found\n' "$label" "$n" >&2
  fi

  # Debug only → dump output
  if [[ "$level" == "debug" ]]; then
    # Debug header
    log_debug_prefix >&2
    printf ' %s output (begin)\n' "$label" >&2
    # Print each line in debug color format
    while IFS='' read -r line; do
      printf '%bDEBUG:%b | %s%b\n' \
        "$LOG_BLUE" "$LOG_REAL_YELLOW" "$line" "$LOG_RESET" >&2
    done <<< "$out"
    # Debug footer
    log_debug_prefix >&2
    printf ' %s output (end)\n' "$label" >&2
  fi


  # Printing the output of actual command which will be used in slurm.sh instead of running the command again there.
  printf '%s\n' "$out"
}
