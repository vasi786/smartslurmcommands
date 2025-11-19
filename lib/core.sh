#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

SSC_HOME="${SSC_HOME:-"$(cd "$(dirname "$0")/../.." && pwd)"}"
source "$SSC_HOME/lib/log.sh"


require_cmd() { command -v "$1" >/dev/null 2>&1 || die 5 "missing dependency: $1"; }

die() {
  local code="$1"; shift
  # use log_error if available, else fallback
  if command -v log_error >/dev/null 2>&1; then
    log_error "$*"
  else
    printf 'ERROR: %s\n' "$*" >&2
  fi
  exit "$code"
}
