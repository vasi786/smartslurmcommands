#!/usr/bin/env bats
setup() { source "$BATS_TEST_DIRNAME/../helpers/bats_helpers.bash"; }

@test "util::filter_candidates_by_partition matches single partition" {
  run bash -lc '
    source "$SSC_HOME/lib/util.sh"
    printf "%s\n" "1|foo|RUNNING|/x|00:10|2025-11-12|reason|genoa" \
                  "2|bar|RUNNING|/x|00:20|2025-11-12|reason|rome" \
      | util::filter_candidates_by_partition genoa
  '
  [ "$status" -eq 0 ]
  [ "$output" = "1|foo|RUNNING|/x|00:10|2025-11-12|reason|genoa" ]
}

@test "util::filter_candidates_by_partition matches multiple partitions" {
  run bash -lc '
    source "$SSC_HOME/lib/util.sh"
    printf "%s\n" "1|foo|RUNNING|/x|00:10|2025-11-12|reason|genoa" \
                  "2|bar|RUNNING|/x|00:20|2025-11-12|reason|rome" \
                  "3|baz|RUNNING|/x|00:30|2025-11-12|reason|naples" \
      | util::filter_candidates_by_partition "rome,genoa"
  '
  [ "$status" -eq 0 ]
  [ "$output" = $'1|foo|RUNNING|/x|00:10|2025-11-12|reason|genoa\n2|bar|RUNNING|/x|00:20|2025-11-12|reason|rome' ]
}

@test "util::filter_candidates_by_partition strips trailing asterisk" {
  run bash -lc '
    source "$SSC_HOME/lib/util.sh"
    printf "%s\n" "1|foo|RUNNING|/x|00:10|2025-11-12|reason|genoa*" \
                  "2|bar|RUNNING|/x|00:20|2025-11-12|reason|rome" \
      | util::filter_candidates_by_partition genoa
  '
  [ "$status" -eq 0 ]
  [ "$output" = "1|foo|RUNNING|/x|00:10|2025-11-12|reason|genoa*" ]
}
