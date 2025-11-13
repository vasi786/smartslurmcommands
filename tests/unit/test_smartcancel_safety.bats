#!/usr/bin/env bats

setup() {
  export PATH_ORIG="$PATH"

  # load helpers: this sets SSC_HOME by walking up to repo root
  source "$BATS_TEST_DIRNAME/../helpers/bats_helpers.bash"

  # prepend slurm mocks to PATH (squeue/scancel)
  source "$BATS_TEST_DIRNAME/../helpers/mock_path.bash"
  mock_slurm_path

  # make sure the script is executable (in case git didn't preserve +x)
  chmod +x "$SSC_HOME/cmd/smartcancel/smartcancel.sh"
}

teardown() {
  export PATH="$PATH_ORIG"
}

@test "smartcancel refuses with no selector" {
  run "$SSC_HOME/cmd/smartcancel/smartcancel.sh" --dry-run
  [ "$status" -eq 2 ]
  [[ "$output" =~ Refusing\ to\ operate\ with\ no\ selector ]]
}
