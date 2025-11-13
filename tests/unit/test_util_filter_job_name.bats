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
@test "util::filter_candidates_by_field_values exact match" {
  run bash -lc '
    source "$SSC_HOME/lib/util.sh"
    printf "%s\n" "1|alpha|X" "2|beta|Y" "3|gamma|Z" \
      | util::filter_candidates_by_field_values 2 beta
  '
  echo "output is $output"
  [ "$status" -eq 0 ]
  [ "$output" = "2|beta|Y" ]
}

@test "util::filter_candidates_by_field_contains one substring" {
  run bash -lc '
    source "$SSC_HOME/lib/util.sh"
    printf "%s\n" "1|alpha|X" "2|beta|Y" "3|gamma|Z" \
      | util::filter_candidates_by_field_contains 2 mm
  '
  [ "$status" -eq 0 ]
  [ "$output" = "3|gamma|Z" ]
}

@test "util::filter_candidates_by_field_contains many substrings" {
  run bash -lc '
    source "$SSC_HOME/lib/util.sh"
    printf "%s\n" "1|alpha|X" "2|beta|Y" "3|gamma|Z" \
      | util::filter_candidates_by_field_contains 2 ta mm
  '
  [ "$status" -eq 0 ]
  # order preserved from input
  [ "$output" = $'2|beta|Y\n3|gamma|Z' ]
}
