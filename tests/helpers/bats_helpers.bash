# tests/helpers/bats_helpers.bash
# Robustly locate repo root (directory that contains lib/util.sh) by
# walking up from the current test's directory.
#
# # Tip: When running a login shell (`bash -lc`) from Bats, pass vars via env:
#   run env VAR=value bash -lc '...'
# Direct VAR=value before the command does not propagate inside -lc.

tests::repo_root() {
  # BATS sets BATS_TEST_DIRNAME; fallback to this file's dir
  local dir="${BATS_TEST_DIRNAME:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)}"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/lib/util.sh" ]]; then
      printf '%s\n' "$dir"
      return 0
    fi
    dir="$(cd "$dir/.." && pwd -P)"
  done
  return 1
}

# Resolve SSC_HOME once, export for child shells
if [[ -z "${SSC_HOME:-}" ]]; then
  SSC_HOME="$(tests::repo_root)" || {
    echo "ERROR: could not locate repo root from ${BATS_TEST_DIRNAME:-unknown}" >&2
    exit 1
  }
fi
export SSC_HOME

# Minimal shared bootstrap for unit tests
tests_source_libs() {
  # no -e/-u: let Bats capture failures cleanly
  source "$SSC_HOME/lib/util.sh"
  source "$SSC_HOME/lib/slurm.sh"
}
