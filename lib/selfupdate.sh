#!/usr/bin/env bash
# shellcheck shell=bash

SSC_HOME="${SSC_HOME:-"$(cd "$(dirname "$0")/../.." && pwd)"}"
source "$SSC_HOME/lib/core.sh"
source "$SSC_HOME/lib/util.sh"
source "$SSC_HOME/lib/log.sh"


# GitHub repo to pull releases from (can be overridden by env)
SSC_REPO="${SSC_REPO:-vasi786/smartslurmcommands}"

ssc::self_update_usage() {
  cat <<EOF
Usage: ssc --update [--tag TAG]

Update smartslurmcommands from GitHub releases.

  --tag TAG      Install a specific release tag (e.g. v0.2.1).
                 If omitted, the latest release tag is used.

Examples:
  ssc --update
  ssc --update --tag v0.2.1
EOF
}

ssc::self_update() {
  local tag=""
  # Parse optional flags to --update
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tag)
        [[ $# -ge 2 ]] || die 2 "ssc --update --tag requires an argument"
        tag="$2"
        shift 2
        ;;
      -h|--help)
        ssc::self_update_usage
        return 0
        ;;
      *)
        die 2 "ssc --update: unknown option '$1' (see ssc --update --help)"
        ;;
    esac
  done

  require_cmd curl
  require_cmd tar

  local target_tag
  if [[ -n "$tag" ]]; then
    target_tag="$tag"
  else
    log_info "Checking latest release from GitHub ($SSC_REPO)..."
    local json
    if ! json="$(curl -fsSL "https://api.github.com/repos/$SSC_REPO/releases/latest")"; then
      log_error "Failed to query GitHub releases."
      return 1
    fi
    target_tag="$(printf '%s\n' "$json" | awk -F'"' '/"tag_name":/ {print $4; exit}')"
    if [[ -z "$target_tag" ]]; then
      log_error "Could not parse latest tag from GitHub response."
      return 1
    fi
  fi

  local current="(unknown)"
  if [[ -f "$SSC_HOME/VERSION" ]]; then
    current="$(cat "$SSC_HOME/VERSION" 2>/dev/null || echo "(unknown)")"
  fi
  current="v${current}"

  log_info "Current version: $current"
  log_info "Target version : $target_tag"

  # Only auto-skip when user did NOT explicitly pick a tag
  if [[ -z "$tag" && "$current" == "$target_tag" ]]; then
    log_info "Already up to date."
    return 0
  fi

  local tmpdir
  tmpdir="$(mktemp -d)" || { log_error "mktemp failed"; return 1; }
  log_debug "Using temp dir: $tmpdir"

  local url="https://github.com/$SSC_REPO/archive/refs/tags/$target_tag.tar.gz"
  local tarball="$tmpdir/src.tar.gz"

  log_info "Downloading $url"
  if ! curl -fsSL "$url" -o "$tarball"; then
    log_error "Download failed."
    rm -rf "$tmpdir"
    return 1
  fi

  if ! tar -xzf "$tarball" -C "$tmpdir"; then
    log_error "Extraction failed."
    rm -rf "$tmpdir"
    return 1
  fi

  # Find extracted source dir (smartslurmcommands-<tag> or similar)
  local srcdir
  srcdir="$(find "$tmpdir" -maxdepth 1 -type d -name 'smartslurmcommands-*' | head -n 1)"
  if [[ -z "$srcdir" ]]; then
    log_error "Could not locate extracted smartslurmcommands directory."
    rm -rf "$tmpdir"
    return 1
  fi

  if [[ ! -x "$srcdir/scripts/install.sh" ]]; then
    log_error "install.sh not found or not executable in $srcdir/scripts."
    rm -rf "$tmpdir"
    return 1
  fi

  log_info "Running installer from $srcdir"
  # Use ~/.local as default prefix (same as your install.sh)
  if ! (cd "$srcdir" && ./scripts/install.sh); then
    log_error "Installer failed."
    rm -rf "$tmpdir"
    return 1
  fi

  log_info "Update to $target_tag complete."
  rm -rf "$tmpdir"
}
