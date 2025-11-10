#!/usr/bin/env bats

@test "smartcancel shows help" {
  run "smartslurmcommands/bin/smartcancel" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: smartcancel"* ]]
}
