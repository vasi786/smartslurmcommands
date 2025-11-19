#!/usr/bin/env bats

setup() {
  # sets SSC_HOME and helper funcs
  source "$BATS_TEST_DIRNAME/../helpers/bats_helpers.bash"
  tests_source_libs
}

@test "filter_candidates_by_field_regex: matches foo_* and baz_* by regex" {
  run bash -lc '
    source "$SSC_HOME/lib/util.sh"

    rows=$'"'"'1001|foo_run|RUNNING|/w/dirA|00:12:34|2025-11-10T10:00:00|tcn[1-2]|genoa
1002|foo_old|RUNNING|/w/dirA|2-03:04:05|2025-11-08T09:00:00|tcn[5]|genoa*
1003|foo_pending|PENDING|/w/dirA|0:00|N/A|(Priority)|genoa
1582|bar_dep|PENDING|/w/dirB|0:00|N/A|(Dependency)|genoa
1012|bar_run|RUNNING|/w/dirB|00:00:05|2025-11-10T10:05:00|tcn[7]|genoa
1583|baz_long|RUNNING|/w/dirC|1-02:03:04|2025-11-09T08:00:00|tcn[3]|rome
1022|baz_short|RUNNING|/w/dirC|00:00:50|2025-11-10T10:10:00|tcn[4]|rome
1023|baz_fail|FAILED|/w/dirC|00:59|2025-11-10T09:50:00|N/A|rome
1031|alpha_test|RUNNING|/w/dirD|00:20:00|2025-11-10T09:40:00|tcn[8]|arm64
1032|alpha_other|PENDING|/w/dirD|0:00|N/A|(Dependency)|arm64
'"'"'

    printf "%s\n" "$rows" \
      | util::filter_candidates_by_field_regex 2 "^foo_" "^baz_"
  '

  [ "$status" -eq 0 ]

  # Should include all foo_* and baz_* jobs
  [[ "$output" =~ foo_run ]]
  [[ "$output" =~ foo_old ]]
  [[ "$output" =~ foo_pending ]]
  [[ "$output" =~ baz_long ]]
  [[ "$output" =~ baz_short ]]
  [[ "$output" =~ baz_fail ]]

  # Should not include bar* or alpha*
  [[ ! "$output" =~ bar_dep ]]
  [[ ! "$output" =~ bar_run ]]
  [[ ! "$output" =~ alpha_test ]]
  [[ ! "$output" =~ alpha_other ]]
}

@test "filter_candidates_by_field_regex: no patterns -> passthrough" {
  run bash -lc '
    source "$SSC_HOME/lib/util.sh"

    rows=$'"'"'1001|foo_run|RUNNING|/w/dirA|00:12:34|2025-11-10T10:00:00|tcn[1-2]|genoa
1002|foo_old|RUNNING|/w/dirA|2-03:04:05|2025-11-08T09:00:00|tcn[5]|genoa*
'"'"'

    printf "%s\n" "$rows" \
      | util::filter_candidates_by_field_regex 2
  '
  [ "$status" -eq 0 ]
  [ "$output" = $'1001|foo_run|RUNNING|/w/dirA|00:12:34|2025-11-10T10:00:00|tcn[1-2]|genoa\n1002|foo_old|RUNNING|/w/dirA|2-03:04:05|2025-11-08T09:00:00|tcn[5]|genoa*' ]
}
