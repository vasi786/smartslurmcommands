#!/usr/bin/env bash

# io.sh - Io library module
# --- Minimal fallbacks if io.sh/log.sh aren’t sourced
command -v confirm >/dev/null 2>&1 || confirm() {
  local prompt="${1:-Continue?}"
  # try to read from /dev/tty first so pipes don’t break prompts
  printf '%s [y/N] ' "$prompt" >&2
  local ans
  if ! IFS= read -r ans </dev/tty 2>/dev/null; then
    IFS= read -r ans || true
  fi
  [[ "$ans" =~ ^([yY]|[yY][eE][sS])$ ]]
}
command -v log_info >/dev/null 2>&1 || log_info(){ printf 'info: %s\n' "$*" >&2; }
command -v log_warn >/dev/null 2>&1 || log_warn(){ printf 'warn: %s\n' "$*" >&2; }
