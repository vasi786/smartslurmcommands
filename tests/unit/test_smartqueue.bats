#!/usr/bin/env bats

@test "smartqueue shows help" {
  run "smartslurmcommands/bin/smartqueue" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: smartqueue"* ]]
}
