#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../helpers/bats_helpers.bash"
  PROJECT_ROOT="$SSC_HOME"
  TEST_ROOT="$(mktemp -d)"
  TEST_PREFIX="$TEST_ROOT/prefix"
  INSTALLED_ROOT="$TEST_PREFIX/share/smartslurmcommands"
  TEST_HOME="$TEST_ROOT/home"
  TEST_TMP="$TEST_ROOT/tmp"
  mkdir -p "$INSTALLED_ROOT/cmd" "$TEST_HOME" "$TEST_TMP" "$TEST_ROOT/fixtures"
  cp -R "$PROJECT_ROOT/lib" "$INSTALLED_ROOT/"
  cp -R "$PROJECT_ROOT/cmd/ssc" "$INSTALLED_ROOT/cmd/"
  printf '0.2.5\n' >"$INSTALLED_ROOT/VERSION"

  COMMIT_A="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  COMMIT_B="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  COMMIT_C="cccccccccccccccccccccccccccccccccccccccc"
  printf '%s\n' "$COMMIT_A" >"$INSTALLED_ROOT/BUILD_COMMIT"
  printf 'old installation\n' >"$INSTALLED_ROOT/LOCAL_MARKER"

  MOCK_COMMIT_JSON="$TEST_ROOT/fixtures/commit.json"
  MOCK_COMPARE_JSON="$TEST_ROOT/fixtures/compare.json"
  MOCK_UPDATE_ARCHIVE="$TEST_ROOT/fixtures/source.tar.gz"
  MOCK_CURL_LOG="$TEST_ROOT/curl.log"
  : >"$MOCK_CURL_LOG"

  export PROJECT_ROOT TEST_ROOT TEST_PREFIX INSTALLED_ROOT TEST_HOME TEST_TMP
  export COMMIT_A COMMIT_B COMMIT_C
  export MOCK_COMMIT_JSON MOCK_COMPARE_JSON MOCK_UPDATE_ARCHIVE MOCK_CURL_LOG
  export SSC_HOME="$INSTALLED_ROOT"
  export HOME="$TEST_HOME"
  export TMPDIR="$TEST_TMP"
  export PATH="$PROJECT_ROOT/tests/helpers/update_mocks:$PATH"
  unset MOCK_COMMIT_FAIL MOCK_COMPARE_FAIL MOCK_ARCHIVE_FAIL
}

teardown() {
  rm -rf "$TEST_ROOT"
}

write_commit_response() {
  local commit="$1" message="${2:-Remote commit}"
  printf '{\n  "sha": "%s",\n  "commit": {\n    "message": "%s"\n  }\n}\n' \
    "$commit" "$message" >"$MOCK_COMMIT_JSON"
}

write_compare_response() {
  local target_commit="${1:-$COMMIT_B}"
  local intermediate_commit="1111111111111111111111111111111111111111"
  cat >"$MOCK_COMPARE_JSON" <<EOF
{
  "status": "ahead",
  "ahead_by": 2,
  "commits": [
    {
      "sha": "$intermediate_commit",
      "commit": {
        "message": "First updater fix"
      }
    },
    {
      "sha": "$target_commit",
      "commit": {
        "message": "Second updater fix\\n\\nDetails"
      }
    }
  ],
  "files": []
}
EOF
}

make_update_archive() {
  local version="$1"
  local source_dir="$TEST_ROOT/archive-source/smartslurmcommands-remote"
  rm -rf "$TEST_ROOT/archive-source"
  mkdir -p "$source_dir"
  cp -R "$PROJECT_ROOT/bin" "$source_dir/"
  cp -R "$PROJECT_ROOT/cmd" "$source_dir/"
  cp -R "$PROJECT_ROOT/docs" "$source_dir/"
  cp -R "$PROJECT_ROOT/etc" "$source_dir/"
  cp -R "$PROJECT_ROOT/lib" "$source_dir/"
  cp -R "$PROJECT_ROOT/man" "$source_dir/"
  cp -R "$PROJECT_ROOT/scripts" "$source_dir/"
  cp "$PROJECT_ROOT/config" "$source_dir/config"
  printf '%s\n' "$version" >"$source_dir/VERSION"
  chmod +x "$source_dir/scripts/install.sh"
  tar -czf "$MOCK_UPDATE_ARCHIVE" -C "$TEST_ROOT/archive-source" smartslurmcommands-remote
}

run_update() {
  run bash "$SSC_HOME/cmd/ssc/ssc.sh" --update "$@"
}

@test "already-current main performs one check and no installation" {
  write_commit_response "$COMMIT_A" "Already installed"

  run_update

  [ "$status" -eq 0 ]
  [[ "$output" =~ already\ up\ to\ date ]]
  [[ "$output" =~ Commit\ \ :\ aaaaaaa ]]
  [ -f "$INSTALLED_ROOT/LOCAL_MARKER" ]
  [ "$(wc -l <"$MOCK_CURL_LOG" | tr -d ' ')" -eq 1 ]
  [[ "$(cat "$MOCK_CURL_LOG")" =~ /commits/main$ ]]
}

@test "same semantic version with a newer main commit updates and records revision" {
  write_commit_response "$COMMIT_B" "Newest main commit"
  write_compare_response "$COMMIT_B"
  make_update_archive 0.2.5

  run_update

  [ "$status" -eq 0 ]
  [[ "$output" =~ Update\ available ]]
  [[ "$output" =~ Installed: ]]
  [[ "$output" =~ Latest\ main: ]]
  [[ "$output" =~ First\ updater\ fix ]]
  [[ "$output" =~ Second\ updater\ fix ]]
  [[ "$output" =~ Updated\ SmartSlurmCommands\ successfully ]]
  [ "$(cat "$INSTALLED_ROOT/VERSION")" = "0.2.5" ]
  [ "$(cat "$INSTALLED_ROOT/BUILD_COMMIT")" = "$COMMIT_B" ]
  [ ! -f "$INSTALLED_ROOT/LOCAL_MARKER" ]
  [[ "$(cat "$MOCK_CURL_LOG")" =~ /tarball/$COMMIT_B ]]
  [ "$(wc -l <"$MOCK_CURL_LOG" | tr -d ' ')" -eq 3 ]
  [ ! -e "$HOME/.local/share/smartslurmcommands" ]
}

@test "new semantic version on main reports and installs the newer version" {
  write_commit_response "$COMMIT_C" "Release version on main"
  write_compare_response "$COMMIT_C"
  make_update_archive 0.2.6

  run_update

  [ "$status" -eq 0 ]
  [[ "$output" =~ Version\ :\ 0.2.5 ]]
  [[ "$output" =~ Version\ :\ 0.2.6 ]]
  [[ "$output" =~ Commit\ \ :\ ccccccc ]]
  [ "$(cat "$INSTALLED_ROOT/VERSION")" = "0.2.6" ]
  [ "$(cat "$INSTALLED_ROOT/BUILD_COMMIT")" = "$COMMIT_C" ]
}

@test "legacy installation without commit metadata remains upgradeable" {
  rm "$INSTALLED_ROOT/BUILD_COMMIT"
  write_commit_response "$COMMIT_B" "Initialize metadata"
  make_update_archive 0.2.5

  run_update

  [ "$status" -eq 0 ]
  [[ "$output" =~ Installed\ commit\ information\ is\ unavailable ]]
  [ "$(cat "$INSTALLED_ROOT/BUILD_COMMIT")" = "$COMMIT_B" ]
  ! grep -q '/compare/' "$MOCK_CURL_LOG"
  [ "$(wc -l <"$MOCK_CURL_LOG" | tr -d ' ')" -eq 2 ]
}

@test "failed update check is not reported as already current" {
  export MOCK_COMMIT_FAIL=true

  run_update

  [ "$status" -ne 0 ]
  [[ "$output" =~ Failed\ to\ query\ GitHub ]]
  [[ ! "$output" =~ already\ up\ to\ date ]]
  [ -f "$INSTALLED_ROOT/LOCAL_MARKER" ]
  [ "$(cat "$INSTALLED_ROOT/BUILD_COMMIT")" = "$COMMIT_A" ]
  [ -z "$(find "$TEST_TMP" -mindepth 1 -print)" ]
}

@test "failed archive download leaves the installed tree untouched" {
  write_commit_response "$COMMIT_B" "Download should fail"
  write_compare_response "$COMMIT_B"
  export MOCK_ARCHIVE_FAIL=true

  run_update

  [ "$status" -ne 0 ]
  [[ "$output" =~ Failed\ to\ download ]]
  [ -f "$INSTALLED_ROOT/LOCAL_MARKER" ]
  [ "$(cat "$INSTALLED_ROOT/BUILD_COMMIT")" = "$COMMIT_A" ]
}

@test "invalid archive is rejected before installation" {
  write_commit_response "$COMMIT_B" "Archive is invalid"
  write_compare_response "$COMMIT_B"
  printf 'not a tar archive\n' >"$MOCK_UPDATE_ARCHIVE"

  run_update

  [ "$status" -ne 0 ]
  [[ "$output" =~ archive\ is\ empty,\ incomplete,\ or\ invalid ]]
  [ -f "$INSTALLED_ROOT/LOCAL_MARKER" ]
  [ "$(cat "$INSTALLED_ROOT/BUILD_COMMIT")" = "$COMMIT_A" ]
  [ -z "$(find "$TEST_TMP" -mindepth 1 -print)" ]
}

@test "commit-summary failure remains informational" {
  write_commit_response "$COMMIT_B" "Summary request should fail"
  make_update_archive 0.2.5
  export MOCK_COMPARE_FAIL=true

  run_update

  [ "$status" -eq 0 ]
  [[ "$output" =~ commit\ summary\ is\ unavailable ]]
  [[ "$output" =~ Updated\ SmartSlurmCommands\ successfully ]]
  [ "$(cat "$INSTALLED_ROOT/BUILD_COMMIT")" = "$COMMIT_B" ]
}

@test "malformed GitHub commit response fails safely" {
  printf '{"message":"unexpected response"}\n' >"$MOCK_COMMIT_JSON"

  run_update

  [ "$status" -ne 0 ]
  [[ "$output" =~ malformed\ commit\ response ]]
  [ -f "$INSTALLED_ROOT/LOCAL_MARKER" ]
  [ "$(cat "$INSTALLED_ROOT/BUILD_COMMIT")" = "$COMMIT_A" ]
}

@test "explicit tag mode resolves and installs the tagged commit" {
  write_commit_response "$COMMIT_C" "Tagged release"
  write_compare_response "$COMMIT_C"
  make_update_archive 0.2.6

  run_update --tag v0.2.6

  [ "$status" -eq 0 ]
  [[ "$output" =~ Target\ tag\ v0.2.6: ]]
  [[ "$(head -n 1 "$MOCK_CURL_LOG")" =~ /commits/v0.2.6$ ]]
  [ "$(cat "$INSTALLED_ROOT/BUILD_COMMIT")" = "$COMMIT_C" ]
}

@test "commit summary is capped at fifteen newest entries" {
  {
    printf '{\n  "commits": [\n'
    for number in $(seq 1 20); do
      printf -v sha '%040x' "$number"
      (( number > 1 )) && printf ',\n'
      printf '    {\n      "sha": "%s",\n' "$sha"
      printf '      "commit": {\n        "message": "Commit %s"\n      }\n    }' "$number"
    done
    printf '\n  ],\n  "files": []\n}\n'
  } >"$MOCK_COMPARE_JSON"

  run bash -c '
    source "$SSC_HOME/lib/selfupdate.sh"
    ssc::parse_commit_summary 15 <"$MOCK_COMPARE_JSON"
  '

  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" -eq 15 ]
  [[ "$output" =~ Commit\ 20 ]]
  [[ ! "$output" =~ Commit\ 1$ ]]
}

@test "ssc --version remains semantic-version-only" {
  run bash "$SSC_HOME/cmd/ssc/ssc.sh" --version

  [ "$status" -eq 0 ]
  [ "$output" = "0.2.5" ]
}
