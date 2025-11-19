#!/usr/bin/env bash
# shellcheck shell=bash

: "${VERBOSE:=false}"

log_debug() {
  $VERBOSE || return 0
  # exactly one string argument is expected
  printf 'DEBUG: %s\n' "$1" >&2
}
