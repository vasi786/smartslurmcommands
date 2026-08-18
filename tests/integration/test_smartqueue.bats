#!/usr/bin/env bats

setup() {
  export PATH_ORIG="$PATH"
  source "$BATS_TEST_DIRNAME/../helpers/bats_helpers.bash"
  source "$BATS_TEST_DIRNAME/../helpers/mock_path.bash"
  mock_slurm_path
}

teardown() {
  export PATH="$PATH_ORIG"
}

@test "smartqueue name filter returns only an exact match" {
  run bash -lc '"$SSC_HOME/cmd/smartqueue/smartqueue.sh" --name baz_long'
  [ "$status" -eq 0 ]
  [[ "$output" =~ baz_long ]]
  [[ ! "$output" =~ baz_short ]]
}

@test "smartqueue regex and partition filters intersect" {
  run bash -lc '"$SSC_HOME/cmd/smartqueue/smartqueue.sh" --regex "^baz_" --partition rome'
  [ "$status" -eq 0 ]
  [[ "$output" =~ baz_long ]]
  [[ "$output" =~ baz_short ]]
  [[ "$output" =~ baz_fail ]]
  [[ ! "$output" =~ foo_run ]]
}

@test "smartqueue partition and state filters intersect" {
  run bash -lc '"$SSC_HOME/cmd/smartqueue/smartqueue.sh" --partition genoa --state pending'
  [ "$status" -eq 0 ]
  [[ "$output" =~ foo_pending ]]
  [[ "$output" =~ bar_dep ]]
  [[ ! "$output" =~ foo_run ]]
  [[ ! "$output" =~ alpha_other ]]
}

@test "smartqueue older-than and state filters intersect" {
  run bash -lc '"$SSC_HOME/cmd/smartqueue/smartqueue.sh" --older-than 1h --state running'
  [ "$status" -eq 0 ]
  [[ "$output" =~ foo_old ]]
  [[ "$output" =~ baz_long ]]
  [[ ! "$output" =~ foo_run ]]
  [[ ! "$output" =~ baz_fail ]]
}

@test "smartqueue older-than and partition filters preserve partition data" {
  run bash -lc '"$SSC_HOME/cmd/smartqueue/smartqueue.sh" --older-than 1h --partition genoa'
  [ "$status" -eq 0 ]
  [[ "$output" =~ foo_old ]]
  [[ ! "$output" =~ baz_long ]]
}

@test "smartqueue name and state filters intersect" {
  run bash -lc '"$SSC_HOME/cmd/smartqueue/smartqueue.sh" --name foo_pending --state pending'
  [ "$status" -eq 0 ]
  [[ "$output" =~ foo_pending ]]
  [[ ! "$output" =~ foo_run ]]
}

@test "smartqueue directory and state filters intersect" {
  run bash -lc '
    tmp="$(mktemp -d)"
    printf "%s\n" "#SBATCH --job-name=foo_run" > "$tmp/run.sh"
    printf "%s\n" "#SBATCH --job-name=foo_pending" > "$tmp/pending.sh"
    "$SSC_HOME/cmd/smartqueue/smartqueue.sh" --dir "$tmp" --state pending
  '
  [ "$status" -eq 0 ]
  [[ "$output" =~ foo_pending ]]
  [[ ! "$output" =~ foo_run ]]
}

@test "smartqueue directory and regex filters intersect" {
  run bash -lc '
    tmp="$(mktemp -d)"
    printf "%s\n" "#SBATCH --job-name=foo_run" > "$tmp/run.sh"
    printf "%s\n" "#SBATCH --job-name=foo_old" > "$tmp/old.sh"
    "$SSC_HOME/cmd/smartqueue/smartqueue.sh" --dir "$tmp" --regex "_old$"
  '
  [ "$status" -eq 0 ]
  [[ "$output" =~ foo_old ]]
  [[ ! "$output" =~ foo_run ]]
}

@test "smartqueue latest considers mixed states" {
  run bash -lc '"$SSC_HOME/cmd/smartqueue/smartqueue.sh" --latest --partition arm64'
  [ "$status" -eq 0 ]
  [[ "$output" =~ alpha_other ]]
  [[ ! "$output" =~ alpha_test ]]
}

@test "smartqueue latest with state preserves explicit state" {
  run bash -lc '"$SSC_HOME/cmd/smartqueue/smartqueue.sh" --latest --state running'
  [ "$status" -eq 0 ]
  [[ "$output" =~ baz_short ]]
  [[ ! "$output" =~ bar_dep ]]
}

@test "smartqueue latest and directory filters intersect" {
  run bash -lc '
    tmp="$(mktemp -d)"
    printf "%s\n" "#SBATCH --job-name=foo_run" > "$tmp/run.sh"
    printf "%s\n" "#SBATCH --job-name=foo_pending" > "$tmp/pending.sh"
    "$SSC_HOME/cmd/smartqueue/smartqueue.sh" --dir "$tmp" --latest
  '
  [ "$status" -eq 0 ]
  [[ "$output" =~ foo_pending ]]
  [[ ! "$output" =~ foo_run ]]
}

@test "smartqueue reports an empty result without querying invalid IDs" {
  run bash -lc '"$SSC_HOME/cmd/smartqueue/smartqueue.sh" --contains does-not-exist'
  [ "$status" -eq 0 ]
  [[ "$output" =~ No\ valid\ job\ IDs\ to\ query ]]
}

@test "smartqueue performs one snapshot query and one formatted render query" {
  count_file="$(mktemp)"
  : > "$count_file"
  run env MOCK_SQUEUE_COUNT_FILE="$count_file" bash -lc \
    '"$SSC_HOME/cmd/smartqueue/smartqueue.sh" --name baz_long'
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$count_file" | tr -d ' ')" -eq 2 ]
  rm -f "$count_file"
}
