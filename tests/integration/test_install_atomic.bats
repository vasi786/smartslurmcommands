#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../helpers/bats_helpers.bash"
  TEST_ROOT="$(mktemp -d)"
  TEST_PREFIX="$TEST_ROOT/prefix"
  TEST_CONFIG_PREFIX="$TEST_ROOT/config"
  OLD_ROOT="$TEST_PREFIX/share/smartslurmcommands"
  mkdir -p "$OLD_ROOT" "$TEST_PREFIX/bin/ssc"
  printf 'working old installation\n' >"$OLD_ROOT/LOCAL_MARKER"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "installer restores the previous shared tree when a post-swap step fails" {
  commit="dddddddddddddddddddddddddddddddddddddddd"

  run env SSC_BUILD_COMMIT="$commit" bash "$SSC_HOME/scripts/install.sh" \
    "$TEST_PREFIX" "$TEST_CONFIG_PREFIX"

  [ "$status" -ne 0 ]
  [ -f "$OLD_ROOT/LOCAL_MARKER" ]
  [ "$(cat "$OLD_ROOT/LOCAL_MARKER")" = "working old installation" ]
  [ ! -f "$OLD_ROOT/BUILD_COMMIT" ]
  [ -z "$(find "$TEST_PREFIX/share" -maxdepth 1 -name '.smartslurmcommands.*' -print)" ]
}

@test "failed first installation removes the staged shared tree" {
  rm -rf "$OLD_ROOT"
  commit="eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"

  run env SSC_BUILD_COMMIT="$commit" bash "$SSC_HOME/scripts/install.sh" \
    "$TEST_PREFIX" "$TEST_CONFIG_PREFIX"

  [ "$status" -ne 0 ]
  [ ! -e "$OLD_ROOT" ]
  [ -z "$(find "$TEST_PREFIX/share" -maxdepth 1 -name '.smartslurmcommands.*' -print)" ]
}
