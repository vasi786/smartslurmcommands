#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../helpers/bats_helpers.bash"
  source "$SSC_HOME/lib/util.sh"
}

@test "filter_candidates_older_than preserves the complete record byte-for-byte" {
  row="1002|foo_old|RUNNING|/path with spaces|2-03:04:05|2025-11-08T09:00:00|node[1-2]|genoa*"

  run env ROW="$row" bash -lc 'source "$SSC_HOME/lib/util.sh"; printf "%s\n" "$ROW" | util::filter_candidates_older_than 1h'

  [ "$status" -eq 0 ]
  [ "$output" = "$row" ]
}

@test "filter_candidates_older_than retains reason for a later dependency filter" {
  rows=$'2001|dep_old|PENDING|/x|02:00:00|N/A|(Dependency)|genoa\n2002|priority_old|PENDING|/x|02:00:00|N/A|(Priority)|genoa'

  run env ROWS="$rows" bash -lc '
    source "$SSC_HOME/lib/util.sh"
    printf "%s\n" "$ROWS" \
      | util::filter_candidates_older_than 1h \
      | awk -F"|" '\''$7 ~ /Dependency/'\''
  '

  [ "$status" -eq 0 ]
  [[ "$output" =~ dep_old ]]
  [[ ! "$output" =~ priority_old ]]
}

@test "pick_latest_line uses StartTime when every candidate has one" {
  rows=$'1001|older|RUNNING|/x|00:10|2025-01-01T10:00:00|n|p\n1002|newer|RUNNING|/x|00:05|2025-01-01T11:00:00|n|p'
  run env ROWS="$rows" bash -lc 'source "$SSC_HOME/lib/util.sh"; printf "%s\n" "$ROWS" | util::pick_latest_line'
  [ "$status" -eq 0 ]
  [[ "$output" =~ newer ]]
}

@test "pick_latest_line falls back to highest JobID for mixed StartTime availability" {
  rows=$'1001|running|RUNNING|/x|00:10|2025-01-01T10:00:00|n|p\n1003|pending|PENDING|/x|0:00|N/A|(Priority)|p'
  run env ROWS="$rows" bash -lc 'source "$SSC_HOME/lib/util.sh"; printf "%s\n" "$ROWS" | util::pick_latest_line'
  [ "$status" -eq 0 ]
  [[ "$output" =~ pending ]]
}

@test "pick_latest_line emits nothing for an empty input" {
  run bash -lc 'source "$SSC_HOME/lib/util.sh"; util::pick_latest_line </dev/null'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
