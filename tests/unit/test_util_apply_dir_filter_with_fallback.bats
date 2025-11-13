#!/usr/bin/env bats

setup() {
  # repo root + util
  source "$BATS_TEST_DIRNAME/../helpers/bats_helpers.bash"
  source "$SSC_HOME/lib/util.sh"

  TMPDIR_UNDER_TEST="$(mktemp -d)"
}

# teardown() {
#   rm -rf "$TMPDIR_UNDER_TEST"
# }

@test "apply_dir_filter_with_fallback: prefers job-name filter when present" {
  dir="$TMPDIR_UNDER_TEST/with_names"
  mkdir -p "$dir"
  dir=$(realpath "$dir")

  # sbatch scripts (top-level only)
  cat > "$dir/a.sh" <<'EOF'
#!/usr/bin/env bash
#SBATCH --job-name alpha
EOF
  cat > "$dir/b.sh" <<'EOF'
#!/usr/bin/env bash
#SBATCH --job-name "beta space"
EOF

  # squeue-like candidates: %i|%j|%T|%Z|%M|%S|%R|%P
  # Note: WorkDir ($4) is arbitrary here; name filtering should take precedence.
  cfile="$TMPDIR_UNDER_TEST/with_names.cands"
  cat > "$cfile" <<'EOF'
10|alpha|RUNNING|/some/path|00:10|N/A|r|genoa
11|beta space|PENDING|/other/path|0:00|N/A|(Dependency)|genoa
12|gamma|RUNNING|/other/path|00:20|N/A|r|rome
EOF

  run env DIR="$dir" CFILE="$cfile" bash -lc '
    source "$SSC_HOME/lib/util.sh"
    cat "$CFILE" | util::apply_dir_filter_with_fallback "$DIR"
  '
  [ "$status" -eq 0 ]
  # Order preserved from input
  [ "$output" = $'10|alpha|RUNNING|/some/path|00:10|N/A|r|genoa\n11|beta space|PENDING|/other/path|0:00|N/A|(Dependency)|genoa' ]
}

@test "apply_dir_filter_with_fallback: falls back to WorkDir match when no job-names" {
  dir="$TMPDIR_UNDER_TEST/no_names"
  mkdir -p "$dir"
  # script without job-name -> forces fallback to WorkDir
  cat > "$dir/empty.sh" <<'EOF'
#!/usr/bin/env bash
# no job-name here
echo ok
EOF

  dir_abs="$(cd "$dir" && pwd)"
  dir_abs=$(realpath "$dir_abs")

  cfile="$TMPDIR_UNDER_TEST/no_names.cands"
  cat > "$cfile" <<EOF
20|alpha|RUNNING|$dir_abs|00:01|N/A|r|genoa
21|beta|PENDING|/elsewhere|0:00|N/A|(Dependency)|rome
EOF

  run env DIR="$dir" CFILE="$cfile" bash -lc '
    source "$SSC_HOME/lib/util.sh"
    cat "$CFILE" | util::apply_dir_filter_with_fallback "$DIR"
  '
  [ "$status" -eq 0 ]
  expected="20|alpha|RUNNING|$dir_abs|00:01|N/A|r|genoa"
  [ "$output" = "$expected" ]
}

@test "apply_dir_filter_with_fallback: empty when neither names nor WorkDir match" {
  dir="$TMPDIR_UNDER_TEST/none"
  mkdir -p "$dir"
  dir=$(realpath "$dir")
  # script without job-name
  printf '#!/usr/bin/env bash\n# nothing\n' > "$dir/nothing.sh"

  cfile="$TMPDIR_UNDER_TEST/none.cands"
  cat > "$cfile" <<'EOF'
30|alpha|RUNNING|/somewhere|00:02|N/A|r|genoa
31|beta|PENDING|/elsewhere|0:00|N/A|(Dependency)|rome
EOF

  run env DIR="$dir" CFILE="$cfile" bash -lc '
    source "$SSC_HOME/lib/util.sh"
    cat "$CFILE" | util::apply_dir_filter_with_fallback "$DIR"
  '
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
