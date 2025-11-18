#!/usr/bin/env bash
# shellcheck shell=bash

# Log levels: error(0) warn(1) info(2) debug(3)
# Default: info; --verbose will bump to debug.

: "${SSC_LOG_LEVEL:=info}"

_log_level_to_num() {
  case "$1" in
    error) echo 0 ;;
    warn)  echo 1 ;;
    info)  echo 2 ;;
    debug) echo 3 ;;
    *)     echo 2 ;;  # fallback to info
  esac
}

_log_enabled() {
  local current wanted
  current="$(_log_level_to_num "${SSC_LOG_LEVEL:-info}")"
  wanted="$(_log_level_to_num "$1")"
  (( current >= wanted ))
}

log_error() {
  _log_enabled error || return 0
  printf 'ERROR: %s\n' "$*" >&2
}

log_warn() {
  _log_enabled warn || return 0
  printf 'WARN: %s\n' "$*" >&2
}

log_info() {
  _log_enabled info || return 0
  printf 'INFO: %s\n' "$*" >&2
}

log_debug() {
  _log_enabled debug || return 0
  printf 'DEBUG: %s\n' "$*" >&2
}
