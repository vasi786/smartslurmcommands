#!/usr/bin/env bats
setup() {
  export PATH_ORIG="$PATH"

  # load helpers: this sets SSC_HOME by walking up to repo root
  source "$BATS_TEST_DIRNAME/../helpers/bats_helpers.bash"

  # prepend slurm mocks to PATH (squeue/scancel)
  source "$BATS_TEST_DIRNAME/../helpers/mock_path.bash"
  mock_slurm_path
}

teardown() {
  export PATH="$PATH_ORIG"
}

@test "stdin patterns with --contains-from-stdin filter candidates" {
  run bash -lc 'printf "%s\n" foo baz | "$SSC_HOME/cmd/smartcancel/smartcancel.sh" --contains-from-stdin --dry-run'
  [ "$status" -eq 0 ]
  # our mock rows include foo_run and baz_long; not bar_dep
  [[ "$output" =~ foo_run ]]
  [[ "$output" =~ baz_long ]]
  [[ ! "$output" =~ bar_dep ]]
}
