#!/usr/bin/env bats

setup() {
  export PATH_ORIG="$PATH"
  source "$BATS_TEST_DIRNAME/../helpers/bats_helpers.bash"
  source "$BATS_TEST_DIRNAME/../helpers/mock_path.bash"
  mock_slurm_path
  export MOCK_DEPENDENCIES=true
}

teardown() {
  export PATH="$PATH_ORIG"
  unset MOCK_DEPENDENCIES
}

@test "selected job with no dependents remains the complete final set" {
  run bash -lc '"$SSC_HOME/cmd/smartcancel/smartcancel.sh" --name alpha_test --dry-run'
  [ "$status" -eq 0 ]
  [[ "$output" =~ alpha_test ]]
  [ "$(grep -c '^scancel ' <<<"$output")" -eq 1 ]
}

@test "one dependent is visible in details and dry-run commands" {
  run bash -lc '"$SSC_HOME/cmd/smartcancel/smartcancel.sh" --name baz_long --dry-run'
  [ "$status" -eq 0 ]
  [[ "$output" =~ baz_long ]]
  [[ "$output" =~ baz_short ]]
  [[ "$output" =~ scancel\ 1583 ]]
  [[ "$output" =~ scancel\ 1022 ]]
}

@test "multiple and recursively chained dependents are all visible" {
  run bash -lc '"$SSC_HOME/cmd/smartcancel/smartcancel.sh" --name foo_run --dry-run'
  [ "$status" -eq 0 ]
  [[ "$output" =~ foo_run ]]
  [[ "$output" =~ foo_old ]]
  [[ "$output" =~ foo_pending ]]
  [[ "$output" =~ bar_dep ]]
  [ "$(grep -c '^scancel ' <<<"$output")" -eq 4 ]
}

@test "confirmation count, preview, and executed IDs use the same expanded set" {
  run bash -lc 'printf "y\n" | "$SSC_HOME/cmd/smartcancel/smartcancel.sh" --name foo_run'
  [ "$status" -eq 0 ]
  [[ "$output" =~ Cancel\ 4\ job\(s\)\? ]]
  for id in 1001 1002 1003 1582; do
    [[ "$output" =~ MOCK\ scancel:\ $id ]]
  done
  [ "$(grep -c 'MOCK scancel:' <<<"$output")" -eq 4 ]
}

@test "--force executes the complete preview without prompting" {
  run bash -lc '"$SSC_HOME/cmd/smartcancel/smartcancel.sh" --name foo_run --force'
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ Cancel\ 4\ job ]]
  [ "$(grep -c 'MOCK scancel:' <<<"$output")" -eq 4 ]
  for id in 1001 1002 1003 1582; do
    [[ "$output" =~ MOCK\ scancel:\ $id ]]
  done
}

@test "dependency expansion uses one squeue snapshot and no per-job scontrol calls" {
  counts="$(mktemp -d)"
  run env MOCK_SQUEUE_COUNT_FILE="$counts/squeue" \
    MOCK_SCONTROL_COUNT_FILE="$counts/scontrol" bash -lc \
    '"$SSC_HOME/cmd/smartcancel/smartcancel.sh" --name foo_run --dry-run'
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$counts/squeue" | tr -d ' ')" -eq 1 ]
  [ ! -e "$counts/scontrol" ]
  rm -rf "$counts"
}
