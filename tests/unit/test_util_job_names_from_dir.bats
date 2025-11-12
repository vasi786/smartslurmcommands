#!/usr/bin/env bats

setup() {
  # locate repo root + load util
  source "$BATS_TEST_DIRNAME/../helpers/bats_helpers.bash"
  source "$SSC_HOME/lib/util.sh"
  TMPDIR_UNDER_TEST="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPDIR_UNDER_TEST"
}

@test "job_names_from_dir: extracts names from various formats (quotes, spaces, symbols)" {
  dir="$TMPDIR_UNDER_TEST/various"
  mkdir -p "$dir"

  # plain equals
  cat > "$dir/a.sh" <<'EOF'
#!/usr/bin/env bash
#SBATCH --job-name=foo_simple
EOF

  # space after key
  cat > "$dir/b.sh" <<'EOF'
#!/usr/bin/env bash
#SBATCH    --job-name   barPlain
EOF

  # double-quoted with spaces
  cat > "$dir/c.sh" <<'EOF'
#!/usr/bin/env bash
#SBATCH --job-name "name with spaces"
EOF

  # single-quoted with symbols
  cat > "$dir/d.sh" <<'EOF'
#!/usr/bin/env bash
#SBATCH --job-name 'symbols_!@#$%^&*()+=,.-_[]{}'
EOF

  # a script without job-name should be ignored
  cat > "$dir/e.sh" <<'EOF'
#!/usr/bin/env bash
# no job-name here
echo "hello"
EOF

  run env DIR="$dir" bash -lc 'source "$SSC_HOME/lib/util.sh"; util::job_names_from_dir "$DIR"'
  [ "$status" -eq 0 ]

  # Expected lines are sorted -u by the function
  expected=$'barPlain\nfoo_simple\nname with spaces\nsymbols_!@#$%^&*()+=,.-_[]{}'
  [ "$output" = "$expected" ]
}

@test "job_names_from_dir: ignores subdirectories (top-level only)" {
   dir="$TMPDIR_UNDER_TEST/top_only"
   mkdir -p "$dir" "$dir/sub"

   cat > "$dir/a.sh" <<'EOF'
#!/usr/bin/env bash
#SBATCH --job-name alpha
EOF

   # This should be ignored (nested)
   cat > "$dir/sub/b.sh" <<'EOF'
#!/usr/bin/env bash
#SBATCH --job-name should_not_be_seen
EOF

   run env DIR="$dir" bash -lc 'source "$SSC_HOME/lib/util.sh"; util::job_names_from_dir "$DIR"'
   [ "$status" -eq 0 ]
   [ "$output" = "alpha" ]
}

@test "job_names_from_dir: deduplicates names across files" {
   dir="$TMPDIR_UNDER_TEST/dedupe"
   mkdir -p "$dir"

   cat > "$dir/a.sh" <<'EOF'
#!/usr/bin/env bash
#SBATCH --job-name repeat
EOF

   cat > "$dir/b.sh" <<'EOF'
#!/usr/bin/env bash
#SBATCH --job-name=repeat
EOF

   run env DIR="$dir" bash -lc 'source "$SSC_HOME/lib/util.sh"; util::job_names_from_dir "$DIR"'
   [ "$status" -eq 0 ]
   [ "$output" = "repeat" ]
 }

 @test "job_names_from_dir: empty directory (no .sh) yields no output and success" {
   dir="$TMPDIR_UNDER_TEST/empty"
   mkdir -p "$dir"

   run env DIR="$dir" bash -lc 'source "$SSC_HOME/lib/util.sh"; util::job_names_from_dir "$DIR"'
   [ "$status" -eq 0 ]
   [ -z "$output" ]
 }
 #
 @test "job_names_from_dir: non-existent directory -> exit 2 with error message" {
   dir="$TMPDIR_UNDER_TEST/does_not_exist"

   run env DIR="$dir" bash -lc 'source "$SSC_HOME/lib/util.sh"; util::job_names_from_dir "$DIR"'
   [ "$status" -eq 2 ]
   [[ "$output" =~ error:\ directory\ not\ found ]]
 }
 #
