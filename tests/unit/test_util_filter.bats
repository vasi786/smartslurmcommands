# tests/unit/test_util_filter.bats
#!/usr/bin/env bats
setup() { source "$BATS_TEST_DIRNAME/../helpers/bats_helpers.bash"; }
@test "util::filter_candidates_by_job_names filters by job name" {
  run bash -lc '
    source "$SSC_HOME/lib/util.sh"
    printf "%s\n" "10|foo|R|/x|00:01|N/A|r|genoa" "11|bar|P|/y|0:00|N/A|(Dependency)|genoa" \
      | util::filter_candidates_by_job_names foo
  '
  [ "$status" -eq 0 ]
  [ "$output" = '10|foo|R|/x|00:01|N/A|r|genoa' ]
}
@test "util::filter_candidates_by_job_names filters by job name with a dependency reason" {
  run bash -lc '
    source "$SSC_HOME/lib/util.sh"
    printf "%s\n" "10|foo|R|/x|00:01|N/A|r|genoa" "11|bar|P|/y|0:00|N/A|(Dependency)|genoa" \
      | util::filter_candidates_by_job_names bar
  '
  [ "$status" -eq 0 ]
  [ "$output" = '11|bar|P|/y|0:00|N/A|(Dependency)|genoa' ]
}
