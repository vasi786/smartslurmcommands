#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../helpers/bats_helpers.bash"
  tests_source_libs
}

@test "util::elapsed_to_seconds handles MM:SS" {
  run bash -lc 'source "$SSC_HOME/lib/util.sh"; util::elapsed_to_seconds 12:34'
  [ "$status" -eq 0 ]
  [ "$output" = "754" ]
}

@test "util::elapsed_to_seconds handles HH:MM:SS" {
  run bash -lc 'source "$SSC_HOME/lib/util.sh"; util::elapsed_to_seconds 01:02:03'
  [ "$status" -eq 0 ]
  [ "$output" = "3723" ]
}

@test "util::elapsed_to_seconds handles D-HH:MM:SS" {
  run bash -lc 'source "$SSC_HOME/lib/util.sh"; util::elapsed_to_seconds 1-02:03:04'
  [ "$status" -eq 0 ]
  # 1d = 86400; + 2h =7200; + 3m =180; + 4s =4 -> 93784
  [ "$output" = "93784" ]
}

@test "util::older_than compares correctly" {
  run bash -lc 'source "$SSC_HOME/lib/util.sh"; util::older_than 12:00 10m'
  [ "$status" -eq 0 ]  # 720 > 600
  run bash -lc 'source "$SSC_HOME/lib/util.sh"; util::older_than 09:59 10m'
  [ "$status" -eq 1 ]
}

@test "util::duration_to_seconds handles supported threshold units" {
  run bash -lc 'source "$SSC_HOME/lib/util.sh"; util::duration_to_seconds 30m'
  [ "$status" -eq 0 ]
  [ "$output" = "1800" ]

  run bash -lc 'source "$SSC_HOME/lib/util.sh"; util::duration_to_seconds 2d'
  [ "$status" -eq 0 ]
  [ "$output" = "172800" ]
}

@test "younger-than is strict and preserves complete records" {
  run bash -lc '
    source "$SSC_HOME/lib/util.sh"
    printf "%s\n" \
      "1|short|RUNNING|/w/a|00:59:59|start|node|p|01:00:01" \
      "2|equal|RUNNING|/w/b|01:00:00|start|node|p|00:30:00" \
      "3|long|RUNNING|/w/c|1-00:00:00|start|node|p|00:10:00" \
      "4|unknown|RUNNING|/w/d|INVALID|start|node|p|00:05:00" \
      | util::filter_candidates_younger_than 1h
  '
  [ "$status" -eq 0 ]
  [ "$output" = "1|short|RUNNING|/w/a|00:59:59|start|node|p|01:00:01" ]
}

@test "time-left excludes equality and non-numeric Slurm values" {
  run bash -lc '
    source "$SSC_HOME/lib/util.sh"
    printf "%s\n" \
      "1|soon|RUNNING|/w/a|00:10:00|start|node|p|00:29:59" \
      "2|equal|RUNNING|/w/b|00:10:00|start|node|p|00:30:00" \
      "3|unlimited|RUNNING|/w/c|00:10:00|start|node|p|UNLIMITED" \
      "4|unset|PENDING|/w/d|0:00|N/A|(Priority)|p|NOT_SET" \
      "5|expired|RUNNING|/w/e|00:10:00|start|node|p|0:00" \
      | util::filter_candidates_time_left 30m
  '
  [ "$status" -eq 0 ]
  [ "$output" = $'1|soon|RUNNING|/w/a|00:10:00|start|node|p|00:29:59\n5|expired|RUNNING|/w/e|00:10:00|start|node|p|0:00' ]
}

@test "time filters reject malformed thresholds" {
  run bash -lc '
    source "$SSC_HOME/lib/util.sh"
    printf "%s\n" "1|job|RUNNING|/w|00:10:00|start|node|p|00:05:00" \
      | util::filter_candidates_time_left soon
  '
  [ "$status" -eq 2 ]
  [[ "$output" =~ invalid\ duration:\ soon ]]
}
