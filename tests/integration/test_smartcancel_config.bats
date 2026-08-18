#!/usr/bin/env bats

setup() {
  export PATH_ORIG="$PATH"
  source "$BATS_TEST_DIRNAME/../helpers/bats_helpers.bash"
  source "$BATS_TEST_DIRNAME/../helpers/mock_path.bash"
  mock_slurm_path
  TEST_CONFIG_HOME="$(mktemp -d)"
  mkdir -p "$TEST_CONFIG_HOME/smartslurmcommands"
}

teardown() {
  export PATH="$PATH_ORIG"
  rm -rf "$TEST_CONFIG_HOME"
}

@test "dry_run=true config prevents real cancellation" {
  printf '%s\n' 'dry_run=true' > "$TEST_CONFIG_HOME/smartslurmcommands/config"
  run env XDG_CONFIG_HOME="$TEST_CONFIG_HOME" bash -lc \
    '"$SSC_HOME/cmd/smartcancel/smartcancel.sh" --name alpha_test --force'
  [ "$status" -eq 0 ]
  [[ "$output" =~ Dry-run\ \(no\ changes\) ]]
  [[ ! "$output" =~ MOCK\ scancel ]]
}

@test "confirm=false config skips the prompt but executes the displayed set" {
  printf '%s\n' 'confirm=false' > "$TEST_CONFIG_HOME/smartslurmcommands/config"
  run env XDG_CONFIG_HOME="$TEST_CONFIG_HOME" bash -lc \
    '"$SSC_HOME/cmd/smartcancel/smartcancel.sh" --name alpha_test'
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ Cancel\ 1\ job ]]
  [[ "$output" =~ MOCK\ scancel:\ 1031 ]]
}

@test "dotted include_dependents config disables recursive expansion" {
  printf '%s\n' 'smartcancel.include_dependents=false' > "$TEST_CONFIG_HOME/smartslurmcommands/config"
  run env XDG_CONFIG_HOME="$TEST_CONFIG_HOME" MOCK_DEPENDENCIES=true bash -lc \
    '"$SSC_HOME/cmd/smartcancel/smartcancel.sh" --name foo_run --dry-run'
  [ "$status" -eq 0 ]
  [[ "$output" =~ foo_run ]]
  [[ ! "$output" =~ foo_old ]]
  [[ ! "$output" =~ foo_pending ]]
  [[ "$output" =~ scancel\ 1001 ]]
  [[ ! "$output" =~ scancel\ 1002 ]]
}

@test "environment override takes precedence over config" {
  printf '%s\n' 'smartcancel.include_dependents=true' > "$TEST_CONFIG_HOME/smartslurmcommands/config"
  run env XDG_CONFIG_HOME="$TEST_CONFIG_HOME" MOCK_DEPENDENCIES=true \
    SSC_SMARTCANCEL_INCLUDE_DEPENDENTS=false bash -lc \
    '"$SSC_HOME/cmd/smartcancel/smartcancel.sh" --name foo_run --dry-run'
  [ "$status" -eq 0 ]
  [[ "$output" =~ scancel\ 1001 ]]
  [[ ! "$output" =~ scancel\ 1002 ]]
}

@test "obsolete cancellation reason is ignored consistently in dry-run and execution" {
  run env SSC_SMARTCANCEL_DEFAULT_REASON='unsafe reason; echo injected' bash -lc \
    '"$SSC_HOME/cmd/smartcancel/smartcancel.sh" --name alpha_test --dry-run'
  [ "$status" -eq 0 ]
  [[ "$output" =~ scancel\ 1031 ]]
  [[ ! "$output" =~ --reason ]]
  [[ ! "$output" =~ injected$ ]]

  run env SSC_SMARTCANCEL_DEFAULT_REASON='unsafe reason; echo injected' bash -lc \
    '"$SSC_HOME/cmd/smartcancel/smartcancel.sh" --name alpha_test --force'
  [ "$status" -eq 0 ]
  [[ "$output" =~ MOCK\ scancel:\ 1031 ]]
  [[ ! "$output" =~ --reason ]]
}
