#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../helpers/bats_helpers.bash"
  source "$SSC_HOME/lib/core.sh"
  source "$SSC_HOME/lib/cfg.sh"
  CFG_TEST_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$CFG_TEST_DIR"
}

@test "config parser accepts dotted keys, whitespace, comments, and quoted booleans" {
  cfg_file="$CFG_TEST_DIR/config"
  cat > "$cfg_file" <<'EOF'
  # comment
  confirm = "false"
  dry_run= true
  smartcancel.include_dependents = 'false'
EOF

  run env CFG_FILE="$cfg_file" bash -lc '
    source "$SSC_HOME/lib/core.sh"
    source "$SSC_HOME/lib/cfg.sh"
    cfg::parse_file "$CFG_FILE"
    printf "%s|%s|%s\n" \
      "$(cfg::get confirm)" \
      "$(cfg::get dry_run)" \
      "$(cfg::get smartcancel.include_dependents)"
  '

  [ "$status" -eq 0 ]
  [ "$output" = "false|true|false" ]
}

@test "config parser safely rejects malformed and unknown keys" {
  cfg_file="$CFG_TEST_DIR/config"
  cat > "$cfg_file" <<'EOF'
no equals sign
bad..key=true
unknown.key=true
confirm="unterminated
dry_run=false
EOF

  run env CFG_FILE="$cfg_file" bash -lc '
    source "$SSC_HOME/lib/core.sh"
    source "$SSC_HOME/lib/cfg.sh"
    cfg::parse_file "$CFG_FILE"
    printf "dry_run=%s unknown=%s bad=%s\n" \
      "$(cfg::get dry_run MISSING)" \
      "$(cfg::get unknown.key MISSING)" \
      "$(cfg::get bad..key MISSING)"
  '

  [ "$status" -eq 0 ]
  [[ "$output" =~ ignored\ malformed\ line ]]
  [[ "$output" =~ ignored\ malformed\ key ]]
  [[ "$output" =~ ignored\ unknown\ key ]]
  [[ "$output" =~ ignored\ unterminated\ quoted\ value ]]
  [[ "$output" =~ dry_run=false\ unknown=MISSING\ bad=MISSING ]]
}

@test "cfg::get returns the requested fallback for a missing key" {
  run bash -lc '
    source "$SSC_HOME/lib/core.sh"
    source "$SSC_HOME/lib/cfg.sh"
    cfg::get confirm fallback
  '
  [ "$status" -eq 0 ]
  [ "$output" = "fallback" ]
}

@test "cfg::get_bool validates supported boolean spellings" {
  run bash -lc '
    source "$SSC_HOME/lib/core.sh"
    source "$SSC_HOME/lib/cfg.sh"
    __CFG[confirm]=yes
    __CFG[dry_run]=OFF
    printf "%s|%s\n" "$(cfg::get_bool confirm)" "$(cfg::get_bool dry_run true)"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "true|false" ]
}

@test "cfg::get_bool rejects an invalid boolean" {
  run bash -lc '
    source "$SSC_HOME/lib/core.sh"
    source "$SSC_HOME/lib/cfg.sh"
    __CFG[confirm]=maybe
    cfg::get_bool confirm
  '
  [ "$status" -eq 2 ]
  [[ "$output" =~ Invalid\ boolean\ value ]]
}
