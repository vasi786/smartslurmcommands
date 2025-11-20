#!/usr/bin/env bats

setup() {
  export PATH_ORIG="$PATH"

  # sets SSC_HOME and helpers
  source "$BATS_TEST_DIRNAME/../helpers/bats_helpers.bash"
  tests_source_libs

  # prepend our slurm mocks (squeue/scancel)
  source "$BATS_TEST_DIRNAME/../helpers/mock_path.bash"
  mock_slurm_path
}

teardown() {
  export PATH="$PATH_ORIG"
}

# --------------------------------------------------------------------
# --contains-from-stdin + --sep
# --------------------------------------------------------------------

@test "--contains-from-stdin with --sep ';' splits patterns foo;alpha" {
  run bash -lc '
    printf "%s" "foo;alpha" \
      | "$SSC_HOME/cmd/smartcancel/smartcancel.sh" \
          --contains-from-stdin \
          --sep ";" \
          --dry-run
  '
  [ "$status" -eq 0 ]

  # All foo* and alpha* jobs should appear
  [[ "$output" =~ foo_run ]]
  [[ "$output" =~ foo_old ]]
  [[ "$output" =~ foo_pending ]]
  [[ "$output" =~ alpha_test ]]
  [[ "$output" =~ alpha_other ]]

  # bar* and baz* should not
  [[ ! "$output" =~ bar_dep ]]
  [[ ! "$output" =~ bar_run ]]
  [[ ! "$output" =~ baz_long ]]
  [[ ! "$output" =~ baz_short ]]
  [[ ! "$output" =~ baz_fail ]]
}

@test "--contains-from-stdin with --sep '#' splits foo#baz#bar" {
  run bash -lc '
    printf "%s" "foo#baz#bar" \
      | "$SSC_HOME/cmd/smartcancel/smartcancel.sh" \
          --contains-from-stdin \
          --sep "#" \
          --dry-run
  '
  [ "$status" -eq 0 ]

  # foo*, baz*, bar* must be there
  [[ "$output" =~ foo_run ]]
  [[ "$output" =~ foo_old ]]
  [[ "$output" =~ foo_pending ]]

  [[ "$output" =~ baz_long ]]
  [[ "$output" =~ baz_short ]]
  [[ "$output" =~ baz_fail ]]

  [[ "$output" =~ bar_dep ]]
  [[ "$output" =~ bar_run ]]

  # alpha* should not
  [[ ! "$output" =~ alpha_test ]]
  [[ ! "$output" =~ alpha_other ]]
}

# --------------------------------------------------------------------
# --regex-from-stdin + --sep
# --------------------------------------------------------------------

@test "--regex-from-stdin with --sep '|' and patterns '^foo_'|'^baz_' matches foo* and baz*" {
  run bash -lc '
    printf "%s" "^foo_|^baz_" \
      | "$SSC_HOME/cmd/smartcancel/smartcancel.sh" \
          --regex-from-stdin \
          --sep "|" \
          --dry-run
  '
  echo "output is: '$output'" >&3
  [ "$status" -eq 0 ]

  # foo* jobs
  [[ "$output" =~ foo_run ]]
  [[ "$output" =~ foo_old ]]
  [[ "$output" =~ foo_pending ]]

  # baz* jobs
  [[ "$output" =~ baz_long ]]
  [[ "$output" =~ baz_short ]]
  [[ "$output" =~ baz_fail ]]

  # bar* and alpha* should not
  [[ ! "$output" =~ bar_dep ]]
  [[ ! "$output" =~ bar_run ]]
  [[ ! "$output" =~ alpha_test ]]
  [[ ! "$output" =~ alpha_other ]]
}

@test "--regex-from-stdin with --sep ';' selects exactly foo_run and baz_long" {
  run bash -lc '
    printf "%s" "^foo_run$;^baz_long$" \
      | "$SSC_HOME/cmd/smartcancel/smartcancel.sh" \
          --regex-from-stdin \
          --sep ";" \
          --dry-run
  '
  [ "$status" -eq 0 ]

  # Must contain exactly foo_run and baz_long among foo*/baz*
  [[ "$output" =~ foo_run ]]
  [[ "$output" =~ baz_long ]]

  [[ ! "$output" =~ foo_old ]]
  [[ ! "$output" =~ foo_pending ]]
  [[ ! "$output" =~ baz_short ]]
  [[ ! "$output" =~ baz_fail ]]

  # And nothing else
  [[ ! "$output" =~ bar_dep ]]
  [[ ! "$output" =~ bar_run ]]
  [[ ! "$output" =~ alpha_test ]]
  [[ ! "$output" =~ alpha_other ]]
}
@test "--contains-from-stdin with tab separator" {
  run bash -lc '
    sep="$(printf "\t")"
    printf "foo\tbaz" \
      | "$SSC_HOME/cmd/smartcancel/smartcancel.sh" \
          --contains-from-stdin \
          --sep "$sep" \
          --dry-run
  '
  [ "$status" -eq 0 ]

  [[ "$output" =~ foo_run ]]
  [[ "$output" =~ baz_long ]]

  [[ ! "$output" =~ alpha_test ]]
}
