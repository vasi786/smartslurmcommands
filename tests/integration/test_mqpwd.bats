#!/usr/bin/env bats
# Integration tests for mqpwd against slurm_mocks/squeue
#
# squeue fixture rows:
# 1001|foo_run|RUNNING|/w/dirA|00:12:34|2025-11-10T10:00:00|tcn[1-2]|genoa|00:47:26
# 1002|foo_old|RUNNING|/w/dirA|2-03:04:05|2025-11-08T09:00:00|tcn[5]|genoa*|00:05:55
# 1003|foo_pending|PENDING|/w/dirA|0:00|N/A|(Priority)|genoa|1-00:00:00
# 1582|bar_dep|PENDING|/w/dirB|0:00|N/A|(Dependency)|genoa|NOT_SET
# 1012|bar_run|RUNNING|/w/dirB|00:00:05|2025-11-10T10:05:00|tcn[7]|genoa|00:59:55
# 1583|baz_long|RUNNING|/w/dirC|1-02:03:04|2025-11-09T08:00:00|tcn[3]|rome|00:10:00
# 1022|baz_short|RUNNING|/w/dirC|00:00:50|2025-11-10T10:10:00|tcn[4]|rome|UNLIMITED
# 1023|baz_fail|FAILED|/w/dirC|00:59|2025-11-10T09:50:00|N/A|rome|00:00
# 1031|alpha_test|RUNNING|/w/dirD|00:20:00|2025-11-10T09:40:00|tcn[8]|arm64|00:30:00
# 1032|alpha_other|PENDING|/w/dirD|0:00|N/A|(Dependency)|arm64|UNLIMITED

setup() {
  export PATH_ORIG="$PATH"

  # sets SSC_HOME by walking up to repo root
  source "$BATS_TEST_DIRNAME/../helpers/bats_helpers.bash"

  # prepend slurm mocks (squeue/scancel) to PATH
  source "$BATS_TEST_DIRNAME/../helpers/mock_path.bash"
  mock_slurm_path
  chmod +x "$SSC_HOME/cmd/mqpwd/mqpwd.sh"
}

teardown() {
  export PATH="$PATH_ORIG"
}

# --------------------------------------------------------------------
# Basic behaviour
# --------------------------------------------------------------------

@test "mqpwd (no args) lists jobs for sbatch job-name in PWD" {
  run bash -lc '
    tmp="$(mktemp -d)"
    cd "$tmp"

    cat > job.sh <<EOF
#!/usr/bin/env bash
#SBATCH --job-name=foo_run
echo hi
EOF
    chmod +x job.sh

    "$SSC_HOME/cmd/mqpwd/mqpwd.sh"
  '
  [ "$status" -eq 0 ]

  # We expect foo_run to be in the table
  [[ "$output" =~ foo_run ]]
}

@test "mqpwd PATH lists jobs for that directory" {
  run bash -lc '
    tmp="$(mktemp -d)"

    cat > "$tmp/other_job.sh" <<EOF
#!/usr/bin/env bash
#SBATCH --job-name=baz_long
echo hi
EOF
    chmod +x "$tmp/other_job.sh"

    "$SSC_HOME/cmd/mqpwd/mqpwd.sh" --dir "$tmp"
  '
  [ "$status" -eq 0 ]

  # We expect baz_long to be present
  [[ "$output" =~ baz_long ]]
}

# --------------------------------------------------------------------
# Edge cases: no job-names / no matches
# --------------------------------------------------------------------

@test "mqpwd: no #SBATCH --job-name in scripts -> message and exit 0" {
  run bash -lc '
    tmp="$(mktemp -d)"
    cd "$tmp"

    cat > plain.sh <<EOF
#!/usr/bin/env bash
echo "no sbatch here"
EOF
    chmod +x plain.sh

    "$SSC_HOME/cmd/mqpwd/mqpwd.sh"
  '
  [ "$status" -eq 0 ]

  # Message is written to stderr in mqpwd implementation
  [[ "$output" =~ No\ jobs\ found\ related\ to ]]
}

@test "mqpwd: job-name not in queue -> 'No matching jobs found in queue.'" {
  run bash -lc '
    tmp="$(mktemp -d)"
    cd "$tmp"

    cat > job.sh <<EOF
#!/usr/bin/env bash
#SBATCH --job-name=not_in_fixture
echo hi
EOF
    chmod +x job.sh

    "$SSC_HOME/cmd/mqpwd/mqpwd.sh"
  '
  [ "$status" -eq 0 ]

  [[ "$output" =~ No\ jobs\ found\ related\ to ]]
}

# --------------------------------------------------------------------
# Argument validation
# --------------------------------------------------------------------

@test "mqpwd: more than one argument fails with status 2" {
  run bash -lc '"$SSC_HOME/cmd/mqpwd/mqpwd.sh" /tmp /tmp'
  [ "$status" -eq 2 ]
}

@test "mqpwd: non-existent directory -> error and non-zero exit" {
  run bash -lc '"$SSC_HOME/cmd/mqpwd/mqpwd.sh" /definitely/does/not/exist'
  [ "$status" -ne 0 ]
  [[ "$output" =~ Directory\ not\ found:\ /definitely/does/not/exist ]]
}

@test "mqpwd --state filters directory-related jobs without unbound variables" {
  run bash -lc '
    tmp="$(mktemp -d)"
    printf "%s\n" "#SBATCH --job-name=foo_run" > "$tmp/run.sh"
    printf "%s\n" "#SBATCH --job-name=foo_pending" > "$tmp/pending.sh"

    "$SSC_HOME/cmd/mqpwd/mqpwd.sh" --dir "$tmp" --state pending
  '
  [ "$status" -eq 0 ]
  [[ "$output" =~ foo_pending ]]
  [[ ! "$output" =~ foo_run ]]
}

@test "mqpwd --regex intersects with the directory selection" {
  run bash -lc '
    tmp="$(mktemp -d)"
    printf "%s\n" "#SBATCH --job-name=foo_run" > "$tmp/run.sh"
    printf "%s\n" "#SBATCH --job-name=foo_old" > "$tmp/old.sh"
    printf "%s\n" "#SBATCH --job-name=foo_pending" > "$tmp/pending.sh"

    "$SSC_HOME/cmd/mqpwd/mqpwd.sh" --dir "$tmp" --regex "^foo_(run|old)$"
  '
  [ "$status" -eq 0 ]
  [[ "$output" =~ foo_run ]]
  [[ "$output" =~ foo_old ]]
  [[ ! "$output" =~ foo_pending ]]
}

@test "mqpwd combines directory, regex, and state as an intersection" {
  run bash -lc '
    tmp="$(mktemp -d)"
    printf "%s\n" "#SBATCH --job-name=foo_run" > "$tmp/run.sh"
    printf "%s\n" "#SBATCH --job-name=foo_old" > "$tmp/old.sh"
    printf "%s\n" "#SBATCH --job-name=foo_pending" > "$tmp/pending.sh"

    "$SSC_HOME/cmd/mqpwd/mqpwd.sh" --dir "$tmp" --regex "^foo_" --state running --older-than 1h
  '
  [ "$status" -eq 0 ]
  [[ "$output" =~ foo_old ]]
  [[ ! "$output" =~ foo_run ]]
  [[ ! "$output" =~ foo_pending ]]
}

@test "mqpwd applies remaining-time filters to directory jobs" {
  run bash -lc '
    tmp="$(mktemp -d)"
    printf "%s\n" "#SBATCH --job-name=baz_long" > "$tmp/long.sh"
    printf "%s\n" "#SBATCH --job-name=baz_short" > "$tmp/short.sh"

    "$SSC_HOME/cmd/mqpwd/mqpwd.sh" --dir "$tmp" --time-left 30m
  '
  [ "$status" -eq 0 ]
  [[ "$output" =~ baz_long ]]
  [[ ! "$output" =~ baz_short ]]
}

@test "mqpwd accepts explicit --this-dir" {
  run bash -lc '
    tmp="$(mktemp -d)"
    cd "$tmp"
    printf "%s\n" "#SBATCH --job-name=baz_long" > job.sh
    "$SSC_HOME/cmd/mqpwd/mqpwd.sh" --this-dir
  '
  [ "$status" -eq 0 ]
  [[ "$output" =~ baz_long ]]
}

@test "mqpwd --verbose and --debug enable filter diagnostics" {
  run bash -lc '
    tmp="$(mktemp -d)"
    printf "%s\n" "#SBATCH --job-name=foo_run" > "$tmp/job.sh"
    "$SSC_HOME/cmd/mqpwd/mqpwd.sh" --dir "$tmp" --verbose
  '
  [ "$status" -eq 0 ]
  [[ "$output" =~ INFO: ]]

  run bash -lc '
    tmp="$(mktemp -d)"
    printf "%s\n" "#SBATCH --job-name=foo_run" > "$tmp/job.sh"
    "$SSC_HOME/cmd/mqpwd/mqpwd.sh" --dir "$tmp" --debug
  '
  [ "$status" -eq 0 ]
  [[ "$output" =~ DEBUG: ]]
}
