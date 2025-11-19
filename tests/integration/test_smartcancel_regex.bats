#!/usr/bin/env bats

setup() {
  export PATH_ORIG="$PATH"

  # sets SSC_HOME and helpers
  source "$BATS_TEST_DIRNAME/../helpers/bats_helpers.bash"
  tests_source_libs

  # prepend our slurm mocks (squeue/scancel)
  source "$BATS_TEST_DIRNAME/../helpers/mock_path.bash"
  mock_slurm_path
}

teardown() {
  export PATH="$PATH_ORIG"
}

# ------------------------------------------------------------
# --regex: single regex pattern
# ------------------------------------------------------------

@test "--regex '^foo_' matches only foo_* family" {
  run bash -lc '"$SSC_HOME/cmd/smartcancel/smartcancel.sh" --regex "^foo_" --dry-run'
  [ "$status" -eq 0 ]

  # All foo_* jobs should appear
  [[ "$output" =~ foo_run ]]
  [[ "$output" =~ foo_old ]]
  [[ "$output" =~ foo_pending ]]

  # None of the others
  [[ ! "$output" =~ bar_dep ]]
  [[ ! "$output" =~ bar_run ]]
  [[ ! "$output" =~ baz_long ]]
  [[ ! "$output" =~ baz_short ]]
  [[ ! "$output" =~ baz_fail ]]
  [[ ! "$output" =~ alpha_test ]]
  [[ ! "$output" =~ alpha_other ]]
}

@test "--regex '^(foo_run|baz_long)$' matches exactly two jobs" {
  run bash -lc '"$SSC_HOME/cmd/smartcancel/smartcancel.sh" --regex "^(foo_run|baz_long)$" --dry-run'
  [ "$status" -eq 0 ]

  # Must contain exactly those two names
  [[ "$output" =~ foo_run ]]
  [[ "$output" =~ baz_long ]]

  [[ ! "$output" =~ foo_old ]]
  [[ ! "$output" =~ foo_pending ]]
  [[ ! "$output" =~ bar_dep ]]
  [[ ! "$output" =~ bar_run ]]
  [[ ! "$output" =~ baz_short ]]
  [[ ! "$output" =~ baz_fail ]]
  [[ ! "$output" =~ alpha_test ]]
  [[ ! "$output" =~ alpha_other ]]
}

# ------------------------------------------------------------
# --regex-from-stdin: patterns via stdin
# ------------------------------------------------------------

@test "--regex-from-stdin with '^foo_' and '^baz_' matches foo_* and baz_*" {
  run bash -lc '
    printf "%s\n" "^foo_" "^baz_" \
      | "$SSC_HOME/cmd/smartcancel/smartcancel.sh" --regex-from-stdin --dry-run
  '
  [ "$status" -eq 0 ]

  # foo_* jobs
  [[ "$output" =~ foo_run ]]
  [[ "$output" =~ foo_old ]]
  [[ "$output" =~ foo_pending ]]

  # baz_* jobs
  [[ "$output" =~ baz_long ]]
  [[ "$output" =~ baz_short ]]
  [[ "$output" =~ baz_fail ]]

  # No bar* or alpha* jobs
  [[ ! "$output" =~ bar_dep ]]
  [[ ! "$output" =~ bar_run ]]
  [[ ! "$output" =~ alpha_test ]]
  [[ ! "$output" =~ alpha_other ]]
}

@test "--regex-from-stdin with complex regex excludes non-matching families" {
  run bash -lc '
    # match foo_* and baz_* RUNNING only (simple example)
    printf "%s\n" "^foo_.*" "^baz_.*" \
      | "$SSC_HOME/cmd/smartcancel/smartcancel.sh" --regex-from-stdin --state running --dry-run
  '
  [ "$status" -eq 0 ]

  # Running foo_* jobs
  [[ "$output" =~ foo_run ]]
  [[ "$output" =~ foo_old ]]
  [[ ! "$output" =~ foo_pending ]]  # pending, filtered out by --state running

  # Running baz_* jobs (baz_long, baz_short)
  [[ "$output" =~ baz_long ]]
  [[ "$output" =~ baz_short ]]
  [[ ! "$output" =~ baz_fail ]]     # FAILED, not RUNNING

  # No bar* or alpha*
  [[ ! "$output" =~ bar_dep ]]
  [[ ! "$output" =~ bar_run ]]
  [[ ! "$output" =~ alpha_test ]]
  [[ ! "$output" =~ alpha_other ]]
}
