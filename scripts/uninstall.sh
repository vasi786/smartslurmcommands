#!/usr/bin/env bash
# uninstall.sh — remove smartslurmcommands from a user prefix (no sudo)
# Usage:
#   ./scripts/uninstall.sh                  # uninstall from ~/.local
#   ./scripts/uninstall.sh --prefix /path   # custom prefix
#   ./scripts/uninstall.sh --yes            # no prompt
#   ./scripts/uninstall.sh --dry-run        # show what would be removed

set -Eeuo pipefail
IFS=$'\n\t'

DEFAULT_PREFIX="${HOME}/.local"
PREFIX="$DEFAULT_PREFIX"
YES=false
DRY=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [--prefix DIR] [--yes] [--dry-run]
Removes files installed by scripts/install.sh:
  - BIN shims:   PREFIX/bin/<command>
  - Share tree:  PREFIX/share/smartslurmcommands
  - Man pages:   PREFIX/share/man/man1/<project manpages>
EOF
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix) PREFIX="$2"; shift 2 ;;
    --yes) YES=true; shift ;;
    --dry-run) DRY=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

BIN_DIR="${PREFIX}/bin"
SHARE_DIR="${PREFIX}/share/smartslurmcommands"
MAN_DIR="${PREFIX}/share/man/man1"

# Minimal confirm fallback (reads from /dev/tty if possible)
confirm() {
  local prompt="${1:-Proceed?}"
  $YES && return 0
  printf "%s [y/N] " "$prompt" >&2
  local ans
  if ! IFS= read -r ans </dev/tty 2>/dev/null; then
    IFS= read -r ans || true
  fi
  [[ "$ans" =~ ^([yY]|yes)$ ]]
}

say() { printf '%s\n' "$*"; }
act_rm() {
  local target="$1"
  if $DRY; then
    say "DRY: rm -f -- $target"
  else
    rm -f -- "$target" 2>/dev/null || true
  fi
}
act_rmdir() {
  local target="$1"
  if $DRY; then
    say "DRY: rmdir --ignore-fail-on-non-empty $target"
  else
    rmdir --ignore-fail-on-non-empty "$target" 2>/dev/null || true
  fi
}

echo "==> Uninstall smartslurmcommands"
echo "    PREFIX   : $PREFIX"
echo "    BIN_DIR  : $BIN_DIR"
echo "    SHARE_DIR: $SHARE_DIR"
echo "    MAN_DIR  : $MAN_DIR"
$DRY && echo "    MODE     : DRY-RUN (no changes)"
echo

# Figure out which commands were installed (from the installed share tree if present)
declare -a CMD_NAMES=()
if [[ -d "$SHARE_DIR/cmd" ]]; then
  while IFS= read -r d; do
    name="$(basename "$d")"
    [[ -n "$name" ]] && CMD_NAMES+=("$name")
  done < <(find "$SHARE_DIR/cmd" -maxdepth 1 -mindepth 1 -type d | sort)
fi

# Fallback: if share tree is missing, try to infer from BIN shim shebangs that point to our share dir
if ((${#CMD_NAMES[@]} == 0)) && [[ -d "$BIN_DIR" ]]; then
  while IFS= read -r f; do
    if grep -q "share/smartslurmcommands/cmd/.*/.*\.sh" "$f" 2>/dev/null; then
      CMD_NAMES+=("$(basename "$f")")
    fi
  done < <(find "$BIN_DIR" -maxdepth 1 -type f -perm -u+x -print)
  # de-dup
  CMD_NAMES=($(printf "%s\n" "${CMD_NAMES[@]}" | sort -u))
fi

# List manpages we installed (use the copy under SHARE_DIR as the source of truth)
declare -a MAN_PAGES=()
if [[ -d "$SHARE_DIR/man" ]]; then
  while IFS= read -r m; do
    MAN_PAGES+=("$(basename "$m")")
  done < <(find "$SHARE_DIR/man" -type f -name '*.1' | sort)
fi

echo "Planned removals:"
if ((${#CMD_NAMES[@]} > 0)); then
  echo "  BIN shims:"
  for n in "${CMD_NAMES[@]}"; do
    echo "    - $BIN_DIR/$n"
  done
else
  echo "  BIN shims: (none detected)"
fi

if [[ -d "$SHARE_DIR" ]]; then
  echo "  Share tree:"
  echo "    - $SHARE_DIR"
else
  echo "  Share tree: (not found)"
fi

if ((${#MAN_PAGES[@]} > 0)); then
  echo "  Man pages:"
  for m in "${MAN_PAGES[@]}"; do
    echo "    - $MAN_DIR/$m"
  done
else
  # fall back to common names if share/man is gone
  echo "  Man pages: (none listed in share; will try common ones)"
fi
echo

confirm "Remove the files above?" || { echo "Aborted."; exit 1; }
echo

# Remove BIN shims
if ((${#CMD_NAMES[@]} > 0)); then
  echo "==> Removing BIN shims"
  for n in "${CMD_NAMES[@]}"; do
    act_rm "$BIN_DIR/$n"
  done
fi

# Remove man pages
echo "==> Removing man pages"
if ((${#MAN_PAGES[@]} > 0)); then
  for m in "${MAN_PAGES[@]}"; do
    act_rm "$MAN_DIR/$m"
  done
else
  # conservative best-effort for known names (adjust as you add more)
  for m in smartcancel.1 mqpwd.1; do
    [[ -f "$MAN_DIR/$m" ]] && act_rm "$MAN_DIR/$m"
  done
fi

# Remove share tree
if [[ -d "$SHARE_DIR" ]]; then
  echo "==> Removing share tree"
  if $DRY; then
    say "DRY: rm -rf -- $SHARE_DIR"
  else
    rm -rf -- "$SHARE_DIR"
  fi
fi

# Tidy potentially empty directories
echo "==> Tidying empty dirs"
act_rmdir "$MAN_DIR"
act_rmdir "$(dirname "$MAN_DIR")"      # PREFIX/share/man
act_rmdir "$BIN_DIR"
act_rmdir "$(dirname "$SHARE_DIR")"    # PREFIX/share

echo
echo "Uninstall complete."
echo
echo "Note: If you added PATH or completion lines in ~/.bashrc manually, they remain."
echo "      Remove lines referencing '${PREFIX}/bin' or 'smartslurmcommands/completions' if you no longer want them."

