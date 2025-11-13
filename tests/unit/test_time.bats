#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../helpers/bats_helpers.bash"
  tests_source_libs
}

@test "time::elapsed_to_seconds handles MM:SS" {
  run bash -lc 'source "$SSC_HOME/lib/util.sh"; time::elapsed_to_seconds 12:34'
  [ "$status" -eq 0 ]
  [ "$output" = "754" ]
}

@test "time::elapsed_to_seconds handles HH:MM:SS" {
  run bash -lc 'source "$SSC_HOME/lib/util.sh"; time::elapsed_to_seconds 01:02:03'
  [ "$status" -eq 0 ]
  [ "$output" = "3723" ]
}

@test "time::elapsed_to_seconds handles D-HH:MM:SS" {
  run bash -lc 'source "$SSC_HOME/lib/util.sh"; time::elapsed_to_seconds 1-02:03:04'
  [ "$status" -eq 0 ]
  # 1d = 86400; + 2h =7200; + 3m =180; + 4s =4 -> 93784
  [ "$output" = "93784" ]
}

@test "time::older_than compares correctly" {
  run bash -lc 'source "$SSC_HOME/lib/util.sh"; time::older_than 12:00 10m'
  [ "$status" -eq 0 ]  # 720 > 600
  run bash -lc 'source "$SSC_HOME/lib/util.sh"; time::older_than 09:59 10m'
  [ "$status" -eq 1 ]
}
