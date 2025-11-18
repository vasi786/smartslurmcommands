#!/usr/bin/env bats
# Integration tests for mqpwd against slurm_mocks/squeue
#
# squeue fixture rows:
# 1001|foo_run|RUNNING|/w/dirA|00:12:34|2025-11-10T10:00:00|tcn[1-2]|genoa
# 1002|foo_old|RUNNING|/w/dirA|2-03:04:05|2025-11-08T09:00:00|tcn[5]|genoa*
# 1003|foo_pending|PENDING|/w/dirA|0:00|N/A|(Priority)|genoa
# 1582|bar_dep|PENDING|/w/dirB|0:00|N/A|(Dependency)|genoa
# 1012|bar_run|RUNNING|/w/dirB|00:00:05|2025-11-10T10:05:00|tcn[7]|genoa
# 1583|baz_long|RUNNING|/w/dirC|1-02:03:04|2025-11-09T08:00:00|tcn[3]|rome
# 1022|baz_short|RUNNING|/w/dirC|00:00:50|2025-11-10T10:10:00|tcn[4]|rome
# 1023|baz_fail|FAILED|/w/dirC|00:59|2025-11-10T09:50:00|N/A|rome
# 1031|alpha_test|RUNNING|/w/dirD|00:20:00|2025-11-10T09:40:00|tcn[8]|arm64
# 1032|alpha_other|PENDING|/w/dirD|0:00|N/A|(Dependency)|arm64

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
}
