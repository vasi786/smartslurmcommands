#!/usr/bin/env bats
setup() { source "$BATS_TEST_DIRNAME/../helpers/bats_helpers.bash"; }

@test "util::filter_by_field keeps rows whose field matches set" {
  run bash -lc '
    source "$SSC_HOME/lib/util.sh"
    printf "%s\n" a b | util::filter_by_field 2 <<< $'"'"$'1|a|X\n2|c|Y\n3|b|Z'"'"'
  '
  [ "$status" -eq 0 ]
  [ "$output" = $'1|a|X\n3|b|Z' ]
}

