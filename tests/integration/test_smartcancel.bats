#!/usr/bin/env bats

setup() {
  export PATH_ORIG="$PATH"

  # sets SSC_HOME by walking up to repo root
  source "$BATS_TEST_DIRNAME/../helpers/bats_helpers.bash"

  # prepend slurm mocks (squeue/scancel) to PATH
  source "$BATS_TEST_DIRNAME/../helpers/mock_path.bash"
  mock_slurm_path
}

teardown() {
  export PATH="$PATH_ORIG"
}

# --------------------------------------------------------------------
# Name-based filters
# --------------------------------------------------------------------

@test "--contains matches all job names containing substring" {
  run bash -lc '"$SSC_HOME/cmd/smartcancel/smartcancel.sh" --contains foo --dry-run'
  [ "$status" -eq 0 ]

  # All foo* jobs should appear
  [[ "$output" =~ foo_run ]]
  [[ "$output" =~ foo_old ]]
  [[ "$output" =~ foo_pending ]]

  # But unrelated families should not be forced in
  [[ ! "$output" =~ baz_long ]]
  [[ ! "$output" =~ baz_short ]]
  [[ ! "$output" =~ baz_fail ]]
  [[ ! "$output" =~ alpha_test ]]
  [[ ! "$output" =~ alpha_other ]]
  [[ ! "$output" =~ bar_dep ]]
  [[ ! "$output" =~ bar_run ]]
}

@test "--name matches exact job name only" {
  run bash -lc '"$SSC_HOME/cmd/smartcancel/smartcancel.sh" --name baz_long --dry-run'
  [ "$status" -eq 0 ]

  # Only baz_long should be present
  [[ "$output" =~ baz_long ]]

  # But unrelated families should not be forced in
  [[ ! "$output" =~ foo_run ]]
  [[ ! "$output" =~ foo_old ]]
  [[ ! "$output" =~ foo_pending ]]
  [[ ! "$output" =~ baz_short ]]
  [[ ! "$output" =~ baz_fail ]]
  [[ ! "$output" =~ alpha_test ]]
  [[ ! "$output" =~ alpha_other ]]
  [[ ! "$output" =~ bar_dep ]]
  [[ ! "$output" =~ bar_run ]]
}

@test "--contains-from-stdin uses patterns from stdin" {
  run bash -lc 'printf "%s\n" foo alpha | "$SSC_HOME/cmd/smartcancel/smartcancel.sh" --contains-from-stdin --dry-run'
  [ "$status" -eq 0 ]

  # All foo* and alpha* jobs should appear
  [[ "$output" =~ foo_run ]]
  [[ "$output" =~ foo_old ]]
  [[ "$output" =~ foo_pending ]]
  [[ "$output" =~ alpha_test ]]
  [[ "$output" =~ alpha_other ]]

  # But baz* and bar* should not appear
  [[ ! "$output" =~ baz_long ]]
  [[ ! "$output" =~ baz_short ]]
  [[ ! "$output" =~ baz_fail ]]
  [[ ! "$output" =~ bar_dep ]]
  [[ ! "$output" =~ bar_run ]]
}

# --------------------------------------------------------------------
# State filters
# --------------------------------------------------------------------

@test "--state running shows only RUNNING jobs" {
  run bash -lc '"$SSC_HOME/cmd/smartcancel/smartcancel.sh" --state running --dry-run'
  [ "$status" -eq 0 ]

  # RUNNING jobs
  [[ "$output" =~ foo_run ]]
  [[ "$output" =~ foo_old ]]
  [[ "$output" =~ bar_run ]]
  [[ "$output" =~ baz_long ]]
  [[ "$output" =~ baz_short ]]
  [[ "$output" =~ alpha_test ]]

  # Non-running jobs should not appear
  [[ ! "$output" =~ foo_pending ]]
  [[ ! "$output" =~ bar_dep ]]
  [[ ! "$output" =~ baz_fail ]]
  [[ ! "$output" =~ alpha_other ]]
}

@test "--state dependency maps to PENDING + reason (Dependency)" {
  run bash -lc '"$SSC_HOME/cmd/smartcancel/smartcancel.sh" --state dependency --dry-run'
  [ "$status" -eq 0 ]

  # We expect dependency jobs
  [[ "$output" =~ bar_dep ]]
  [[ "$output" =~ alpha_other ]]

  # And not general pending jobs with another reason
  [[ ! "$output" =~ foo_pending ]]
  [[ ! "$output" =~ foo_run ]]
  [[ ! "$output" =~ foo_old ]]
  [[ ! "$output" =~ foo_pending ]]
  [[ ! "$output" =~ baz_short ]]
  [[ ! "$output" =~ baz_fail ]]
  [[ ! "$output" =~ baz_long ]]
  [[ ! "$output" =~ alpha_test ]]
  [[ ! "$output" =~ bar_run ]]
}

# --------------------------------------------------------------------
# Duration filter
# --------------------------------------------------------------------

@test "--older-than filters by elapsed time (> 1h)" {
  run bash -lc '"$SSC_HOME/cmd/smartcancel/smartcancel.sh" --older-than 1h --dry-run'
  [ "$status" -eq 0 ]

  # foo_old and baz_long are multi-hour/day jobs
  [[ "$output" =~ foo_old ]]
  [[ "$output" =~ baz_long ]]

  # Short jobs should not be included
  [[ ! "$output" =~ foo_run ]]
  [[ ! "$output" =~ foo_pending ]]
  [[ ! "$output" =~ bar_run ]]
  [[ ! "$output" =~ bar_dep ]]
  [[ ! "$output" =~ baz_short ]]
  [[ ! "$output" =~ baz_fail ]]
  [[ ! "$output" =~ alpha_test ]]
  [[ ! "$output" =~ alpha_other ]]
}

# --------------------------------------------------------------------
# Partition filter
# --------------------------------------------------------------------

@test "--partition genoa matches genoa and genoa* jobs" {
  run bash -lc '"$SSC_HOME/cmd/smartcancel/smartcancel.sh" --partition genoa --dry-run'
  [ "$status" -eq 0 ]

  # All genoa / genoa* jobs
  [[ "$output" =~ foo_run ]]
  [[ "$output" =~ foo_old ]]
  [[ "$output" =~ foo_pending ]]
  [[ "$output" =~ bar_dep ]]
  [[ "$output" =~ bar_run ]]

  # But no rome / arm64 jobs
  [[ ! "$output" =~ baz_long ]]
  [[ ! "$output" =~ baz_short ]]
  [[ ! "$output" =~ baz_fail ]]
  [[ ! "$output" =~ alpha_test ]]
  [[ ! "$output" =~ alpha_other ]]
}

@test "--partition rome selects only baz* jobs" {
  run bash -lc '"$SSC_HOME/cmd/smartcancel/smartcancel.sh" --partition rome --contains baz --dry-run'
  [ "$status" -eq 0 ]

  [[ "$output" =~ baz_long ]]
  [[ "$output" =~ baz_short ]]
  [[ "$output" =~ baz_fail ]]

  [[ ! "$output" =~ foo_run ]]
  [[ ! "$output" =~ foo_old ]]
  [[ ! "$output" =~ foo_pending ]]
  [[ ! "$output" =~ bar_dep ]]
  [[ ! "$output" =~ bar_run ]]
  [[ ! "$output" =~ alpha_test ]]
  [[ ! "$output" =~ alpha_other ]]
}

# --------------------------------------------------------------------
# Latest-job filter
# --------------------------------------------------------------------

@test "--latest returns only newest matching job among foo* family" {
  run bash -lc '"$SSC_HOME/cmd/smartcancel/smartcancel.sh" --latest --contains foo --dry-run'
  [ "$status" -eq 0 ]

  # Should match only the latest foo* job by StartTime (foo_run at 2025-11-10T10:00:00)
  # Ensure foo_run present
  [[ "$output" =~ foo_run ]]

  # Ensure others are not selected
  [[ ! "$output" =~ foo_old ]]
  [[ ! "$output" =~ foo_pending ]]
  [[ ! "$output" =~ bar_run ]]
  [[ ! "$output" =~ bar_dep ]]
  [[ ! "$output" =~ baz_long ]]
  [[ ! "$output" =~ baz_short ]]
  [[ ! "$output" =~ baz_fail ]]
  [[ ! "$output" =~ alpha_test ]]
  [[ ! "$output" =~ alpha_other ]]

  # There should be exactly one scancel line
  n_scancel="$(printf "%s\n" "$output" | grep -c '^scancel ')"
  [ "$n_scancel" -eq 1 ]
}

# --------------------------------------------------------------------
# Directory-based filters (this-dir / dir)
# --------------------------------------------------------------------

@test "--this-dir uses job-name from sbatch scripts in PWD" {
  run bash -lc '
    tmp="$(mktemp -d)"
    cd "$tmp"

    cat > job.sh <<EOF
#!/usr/bin/env bash
#SBATCH --job-name=foo_run
echo hi
EOF
    chmod +x job.sh

    "$SSC_HOME/cmd/smartcancel/smartcancel.sh" --this-dir --dry-run
  '
  [ "$status" -eq 0 ]

  [[ "$output" =~ foo_run ]]
  [[ ! "$output" =~ baz_long ]]
  [[ ! "$output" =~ bar_dep ]]
}

@test "--dir PATH behaves like --this-dir but with explicit path" {
  run bash -lc '
    tmp="$(mktemp -d)"

    cat > "$tmp/other_job.sh" <<EOF
#!/usr/bin/env bash
#SBATCH --job-name=baz_long
echo hi
EOF
    chmod +x "$tmp/other_job.sh"

    "$SSC_HOME/cmd/smartcancel/smartcancel.sh" --dir "$tmp" --dry-run
  '
  [ "$status" -eq 0 ]

  [[ "$output" =~ baz_long ]]
  [[ ! "$output" =~ foo_run ]]
  [[ ! "$output" =~ alpha_test ]]
}

# --------------------------------------------------------------------
# Combined filters
# --------------------------------------------------------------------

@test "combined: --contains foo + --state running restricts to intersection" {
  run bash -lc '"$SSC_HOME/cmd/smartcancel/smartcancel.sh" --contains foo --state running --dry-run'
  [ "$status" -eq 0 ]

  # Running foo* jobs
  [[ "$output" =~ foo_run ]]
  [[ "$output" =~ foo_old ]]

  # Not foo_pending (PENDING)
  [[ ! "$output" =~ foo_pending ]]
}

@test "combined: --partition rome + --older-than 1h keeps only baz_long" {
  run bash -lc '"$SSC_HOME/cmd/smartcancel/smartcancel.sh" --partition rome --older-than 1h --dry-run'
  [ "$status" -eq 0 ]

  [[ "$output" =~ baz_long ]]

  # The short/failed ones should fall out by time filter or state
  [[ ! "$output" =~ baz_short ]]
  [[ ! "$output" =~ baz_fail ]]
}

@test "combined: --this-dir + --state dependency selects dependency jobs for that name" {
  run bash -lc '
    tmp="$(mktemp -d)"
    cd "$tmp"

    cat > dep.sh <<EOF
#!/usr/bin/env bash
#SBATCH --job-name=bar_dep
echo hi
EOF
    chmod +x dep.sh

    "$SSC_HOME/cmd/smartcancel/smartcancel.sh" --this-dir --state dependency --dry-run
  '
  [ "$status" -eq 0 ]

  [[ "$output" =~ bar_dep ]]
  [[ ! "$output" =~ alpha_other ]]  # different name, also dependency, but not from this dir
}

@test "smartcancel refuses with no selector" {
  run "$SSC_HOME/cmd/smartcancel/smartcancel.sh" --dry-run
  [ "$status" -eq 2 ]
  [[ "$output" =~ Refusing\ to\ operate\ with\ no\ filter\ selector ]]
}
