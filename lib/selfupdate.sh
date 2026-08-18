#!/usr/bin/env bash
# shellcheck shell=bash

SSC_HOME="${SSC_HOME:-"$(cd "$(dirname "$0")/../.." && pwd)"}"
source "$SSC_HOME/lib/core.sh"
source "$SSC_HOME/lib/util.sh"
source "$SSC_HOME/lib/log.sh"

SSC_GITHUB_REPO="vasi786/smartslurmcommands"
SSC_GITHUB_API="https://api.github.com/repos/$SSC_GITHUB_REPO"
SSC_COMMIT_SUMMARY_LIMIT=15

ssc::self_update_usage() {
  cat <<'EOF'
Usage: ssc --update [--tag TAG]

Update smartslurmcommands from the canonical GitHub repository.

  With no option, install the latest commit from GitHub main.
  --tag TAG      Install a specific tagged revision (e.g. v0.2.5).

Version is the semantic release version. Commit identifies the exact source
revision, including main-branch commits made after the latest release.

Examples:
  ssc --update
  ssc --update --tag v0.2.5
EOF
}

ssc::read_version() {
  local root="$1"
  if [[ -f "$root/VERSION" ]]; then
    tr -d '[:space:]' <"$root/VERSION"
  else
    printf '(unknown)\n'
  fi
}

ssc::read_installed_commit() {
  local commit=""
  if [[ -f "$SSC_HOME/BUILD_COMMIT" ]]; then
    commit="$(tr -d '[:space:]' <"$SSC_HOME/BUILD_COMMIT")"
    if [[ "$commit" =~ ^[0-9a-f]{40}$ ]]; then
      printf '%s\n' "$commit"
      return 0
    fi
  fi

  # Development checkouts may have Git metadata. Installed archives do not,
  # so Git remains an optional fallback and is never a dependency.
  if [[ -d "$SSC_HOME/.git" ]] && command -v git >/dev/null 2>&1; then
    commit="$(git -C "$SSC_HOME" rev-parse HEAD 2>/dev/null || true)"
    if [[ "$commit" =~ ^[0-9a-f]{40}$ ]]; then
      printf '%s\n' "$commit"
      return 0
    fi
  fi

  return 1
}

ssc::short_commit() {
  local commit="$1"
  if [[ "$commit" =~ ^[0-9a-f]{40}$ ]]; then
    printf '%.7s\n' "$commit"
  else
    printf '(unknown)\n'
  fi
}

ssc::github_request() {
  local url="$1"
  local -a args=(
    -fsSL
    --connect-timeout 10
    --max-time 30
    -H 'Accept: application/vnd.github+json'
    -H 'X-GitHub-Api-Version: 2022-11-28'
  )
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    args+=(-H "Authorization: Bearer $GITHUB_TOKEN")
  fi
  curl "${args[@]}" "$url"
}

ssc::github_download_archive() {
  local commit="$1" destination="$2"
  local -a args=(
    -fL
    --retry 2
    --connect-timeout 10
    --max-time 120
    -H 'Accept: application/vnd.github+json'
    -H 'X-GitHub-Api-Version: 2022-11-28'
    -o "$destination"
  )
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    args+=(-H "Authorization: Bearer $GITHUB_TOKEN")
  fi
  curl "${args[@]}" "$SSC_GITHUB_API/tarball/$commit"
}

ssc::parse_commit_sha() {
  awk -F'"' '
    $2 == "sha" { print $4; exit }
  '
}

ssc::parse_commit_summary() {
  local limit="${1:-$SSC_COMMIT_SUMMARY_LIMIT}"
  awk -F'"' -v limit="$limit" '
    /"commits":[[:space:]]*\[/ { in_commits=1; next }
    in_commits && /"files":[[:space:]]*\[/ { in_commits=0 }
    in_commits && $2 == "sha" && $4 ~ /^[0-9a-f]+$/ {
      sha=$4
      next
    }
    in_commits && sha != "" && $2 == "message" {
      message=$4
      sub(/\\n.*/, "", message)
      entries[++count]=substr(sha, 1, 7) "  " message
      sha=""
    }
    END {
      shown=0
      for (i=count; i>=1 && shown<limit; i--) {
        print entries[i]
        shown++
      }
    }
  '
}

ssc::installation_prefix() {
  local suffix="/share/smartslurmcommands"
  if [[ "$SSC_HOME" == *"$suffix" ]]; then
    local prefix="${SSC_HOME%"$suffix"}"
    printf '%s\n' "${prefix:-/}"
  else
    printf '%s/.local\n' "$HOME"
  fi
}

ssc::print_revision() {
  local label="$1" version="$2" commit="$3"
  printf '%s:\n' "$label"
  printf '  Version : %s\n' "$version"
  printf '  Commit  : %s\n' "$(ssc::short_commit "$commit")"
}

ssc::cleanup_update_dir() {
  local directory="$1"
  [[ -n "$directory" && -d "$directory" ]] && rm -rf -- "$directory"
  return 0
}

ssc::self_update() {
  local tag=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tag)
        [[ $# -ge 2 ]] || die 2 "ssc --update --tag requires an argument"
        tag="$2"
        [[ "$tag" =~ ^[A-Za-z0-9._-]+$ ]] || die 2 "ssc --update: invalid tag '$tag'"
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

  local target_ref="${tag:-main}"
  local target_label="Latest main"
  [[ -n "$tag" ]] && target_label="Target tag $tag"

  printf 'Checking SmartSlurmCommands updates...\n\n'

  local commit_json target_commit
  if ! commit_json="$(ssc::github_request "$SSC_GITHUB_API/commits/$target_ref")"; then
    log_error "Failed to query GitHub commit '$target_ref'. Check connectivity, GitHub availability, and API rate limits."
    return 1
  fi
  target_commit="$(printf '%s\n' "$commit_json" | ssc::parse_commit_sha)"
  if [[ ! "$target_commit" =~ ^[0-9a-f]{40}$ ]]; then
    log_error "GitHub returned a malformed commit response for '$target_ref'."
    return 1
  fi

  local current_version current_commit=""
  current_version="$(ssc::read_version "$SSC_HOME")"
  current_commit="$(ssc::read_installed_commit || true)"

  if [[ -z "$tag" && -n "$current_commit" && "$current_commit" == "$target_commit" ]]; then
    printf 'SmartSlurmCommands is already up to date.\n\n'
    printf 'Version : %s\n' "$current_version"
    printf 'Commit  : %s\n' "$(ssc::short_commit "$current_commit")"
    return 0
  fi

  local commit_summary=""
  if [[ -n "$current_commit" ]]; then
    local compare_json
    if compare_json="$(ssc::github_request "$SSC_GITHUB_API/compare/$current_commit...$target_commit")"; then
      commit_summary="$(printf '%s\n' "$compare_json" | ssc::parse_commit_summary "$SSC_COMMIT_SUMMARY_LIMIT")"
    else
      printf 'Warning: commit summary is unavailable; the update can still continue.\n' >&2
    fi
  fi

  local tmpdir tarball
  tmpdir="$(mktemp -d)" || {
    log_error "Could not create a temporary update directory."
    return 1
  }
  tarball="$tmpdir/source.tar.gz"

  if ! ssc::github_download_archive "$target_commit" "$tarball"; then
    log_error "Failed to download commit $(ssc::short_commit "$target_commit") from GitHub."
    ssc::cleanup_update_dir "$tmpdir"
    return 1
  fi
  if [[ ! -s "$tarball" ]] || ! tar -tzf "$tarball" >/dev/null 2>&1; then
    log_error "Downloaded update archive is empty, incomplete, or invalid."
    ssc::cleanup_update_dir "$tmpdir"
    return 1
  fi
  if ! tar -xzf "$tarball" -C "$tmpdir"; then
    log_error "Failed to extract the validated update archive."
    ssc::cleanup_update_dir "$tmpdir"
    return 1
  fi

  local -a source_dirs=()
  mapfile -t source_dirs < <(find "$tmpdir" -mindepth 1 -maxdepth 1 -type d -print)
  if (( ${#source_dirs[@]} != 1 )); then
    log_error "Update archive does not contain exactly one source directory."
    ssc::cleanup_update_dir "$tmpdir"
    return 1
  fi
  local srcdir="${source_dirs[0]}"
  if [[ ! -x "$srcdir/scripts/install.sh" || ! -f "$srcdir/VERSION" ||
        ! -f "$srcdir/lib/selfupdate.sh" || ! -f "$srcdir/cmd/ssc/ssc.sh" ]]; then
    log_error "Update archive is missing required SmartSlurmCommands files."
    ssc::cleanup_update_dir "$tmpdir"
    return 1
  fi

  local target_version
  target_version="$(ssc::read_version "$srcdir")"
  if [[ ! "$target_version" =~ ^[0-9]+(\.[0-9]+){2}$ ]]; then
    log_error "Update archive contains an invalid VERSION file."
    ssc::cleanup_update_dir "$tmpdir"
    return 1
  fi

  printf 'Update available.\n\n'
  ssc::print_revision "Installed" "$current_version" "$current_commit"
  printf '\n'
  ssc::print_revision "$target_label" "$target_version" "$target_commit"
  if [[ -z "$current_commit" ]]; then
    printf '\nInstalled commit information is unavailable; this update will initialize revision tracking.\n'
  elif [[ -n "$commit_summary" ]]; then
    local summary_count
    summary_count="$(printf '%s\n' "$commit_summary" | sed '/^$/d' | wc -l | tr -d ' ')"
    printf '\nNew commits (%s shown):\n\n' "$summary_count"
    printf '%s\n' "$commit_summary" | sed 's/^/  /'
  fi

  local install_prefix
  install_prefix="$(ssc::installation_prefix)"
  printf '\nUpdating...\n'
  if ! (cd "$srcdir" && SSC_BUILD_COMMIT="$target_commit" ./scripts/install.sh "$install_prefix"); then
    log_error "Installer failed; the previous shared installation was restored."
    ssc::cleanup_update_dir "$tmpdir"
    return 1
  fi

  local installed_root="$install_prefix/share/smartslurmcommands"
  local installed_commit=""
  [[ -f "$installed_root/BUILD_COMMIT" ]] && installed_commit="$(tr -d '[:space:]' <"$installed_root/BUILD_COMMIT")"
  if [[ "$installed_commit" != "$target_commit" ]]; then
    log_error "Update installation completed, but BUILD_COMMIT verification failed."
    ssc::cleanup_update_dir "$tmpdir"
    return 1
  fi

  ssc::cleanup_update_dir "$tmpdir"
  printf '\nUpdated SmartSlurmCommands successfully.\n\n'
  printf 'Version : %s\n' "$target_version"
  printf 'Commit  : %s\n' "$(ssc::short_commit "$target_commit")"
}
