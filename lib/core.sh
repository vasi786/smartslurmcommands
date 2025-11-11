#!/usr/bin/env bash
# shellcheck shell=bash

set -Eeuo pipefail
IFS=$'\n\t'

die() { local code="${1:-1}"; shift || true; printf 'error: %s\n' "$*" >&2; exit "$code"; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || die 5 "missing dependency: $1"; }

