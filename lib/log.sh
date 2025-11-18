#!/usr/bin/env bash
# shellcheck shell=bash

: "${SSC_LOG_LEVEL:=info}"

_log_level_to_num() {
  case "$1" in
    error) echo 0 ;;
    warn)  echo 1 ;;
    info)  echo 2 ;;
    debug) echo 3 ;;
    *)     echo 2 ;;
  esac
}

_log_enabled() {
  local current wanted
  current="$(_log_level_to_num "${SSC_LOG_LEVEL:-info}")"
  wanted="$(_log_level_to_num "$1")"
  (( current >= wanted ))
}

_log_print() {
  # $1 = level label (ERROR/WARN/INFO/DEBUG), rest = message parts
  local level="$1"; shift
  local IFS=' '          # force space-separated join regardless of global IFS
  printf '%s: %s\n' "$level" "$*" >&2
}

log_error() { _log_enabled error || return 0; _log_print "ERROR" "$@"; }
log_warn()  { _log_enabled warn  || return 0; _log_print "WARN"  "$@"; }
log_info()  { _log_enabled info  || return 0; _log_print "INFO"  "$@"; }
log_debug() { _log_enabled debug || return 0; _log_print "DEBUG" "$@"; }
