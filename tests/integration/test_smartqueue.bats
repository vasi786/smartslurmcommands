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

@test "smartqueue younger-than intersects with state" {
  run bash -lc '"$SSC_HOME/cmd/smartqueue/smartqueue.sh" --younger-than 1h --state running'
  [ "$status" -eq 0 ]
  [[ "$output" =~ foo_run ]]
  [[ "$output" =~ bar_run ]]
  [[ ! "$output" =~ foo_old ]]
  [[ ! "$output" =~ baz_long ]]
}

@test "smartqueue time-left excludes equal and unlimited values" {
  run bash -lc '"$SSC_HOME/cmd/smartqueue/smartqueue.sh" --time-left 30m --state running'
  [ "$status" -eq 0 ]
  [[ "$output" =~ foo_old ]]
  [[ "$output" =~ baz_long ]]
  [[ ! "$output" =~ alpha_test ]]
  [[ ! "$output" =~ baz_short ]]
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

@test "smartqueue delegates native squeue options unchanged in one call" {
  count_file="$(mktemp)"
  args_file="$(mktemp)"
  : > "$count_file"
  : > "$args_file"

  run env MOCK_SQUEUE_COUNT_FILE="$count_file" \
    MOCK_SQUEUE_ARGS_FILE="$args_file" bash -lc \
    '"$SSC_HOME/cmd/smartqueue/smartqueue.sh" -u alice -t RUNNING --sort=-t'

  [ "$status" -eq 0 ]
  [ "$(wc -l < "$count_file" | tr -d ' ')" -eq 1 ]
  [ "$(cat "$args_file")" = $'5\t-u\talice\t-t\tRUNNING\t--sort=-t' ]
  rm -f "$count_file" "$args_file"
}

@test "smartqueue delimiter forces native mode for an overlapping option" {
  args_file="$(mktemp)"
  : > "$args_file"

  run env MOCK_SQUEUE_ARGS_FILE="$args_file" bash -lc \
    '"$SSC_HOME/cmd/smartqueue/smartqueue.sh" -- --partition rome'

  [ "$status" -eq 0 ]
  [ "$(cat "$args_file")" = $'2\t--partition\trome' ]
  rm -f "$args_file"
}

@test "smartqueue preserves the native squeue exit status" {
  run env MOCK_SQUEUE_EXIT_STATUS=42 bash -lc \
    '"$SSC_HOME/cmd/smartqueue/smartqueue.sh" --sort=-t'

  [ "$status" -eq 42 ]
}
