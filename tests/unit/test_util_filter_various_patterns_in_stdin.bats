setup() {
  # sets SSC_HOME and helper funcs
  source "$BATS_TEST_DIRNAME/../helpers/bats_helpers.bash"
  tests_source_libs
}

@test "read_patterns_from_stdin: default newline" {
  run bash -lc '
    source "$SSC_HOME/lib/util.sh"

    printf "a\nb\nc" | util::read_patterns_from_stdin
  '
  [ "$status" -eq 0 ]
  [ "$output" = $'a\nb\nc' ]
}

@test "read_patterns_from_stdin: custom separator ';'" {
  run bash -lc '
    source "$SSC_HOME/lib/util.sh"

    printf "foo;bar;baz" | util::read_patterns_from_stdin ";"
  '
  [ "$status" -eq 0 ]
  [ "$output" = $'foo\nbar\nbaz' ]
}
@test "read_patterns_from_stdin: multi-character separator ##" {
  run bash -lc '
    source "$SSC_HOME/lib/util.sh"

    printf "x##y##z" | util::read_patterns_from_stdin "##"
  '
  [ "$status" -eq 0 ]
  [ "$output" = $'x\ny\nz' ]
}

@test "read_patterns_from_stdin: multi-character separator ###" {
  run bash -lc '
    source "$SSC_HOME/lib/util.sh"

    printf "alpha###beta###gamma" | util::read_patterns_from_stdin "###"
  '
  [ "$status" -eq 0 ]
  [ "$output" = $'alpha\nbeta\ngamma' ]
}

@test "read_patterns_from_stdin: separator '|'" {
  run bash -lc '
    source "$SSC_HOME/lib/util.sh"

    printf "foo|bar|baz" | util::read_patterns_from_stdin "|"
  '
  echo "output is: '$output'" >&3
  [ "$status" -eq 0 ]
  [ "$output" = $'foo\nbar\nbaz' ]
}

@test "read_patterns_from_stdin: separator '.*' literal" {
  run bash -lc '
    source "$SSC_HOME/lib/util.sh"

    printf "abc.*def.*ghi" | util::read_patterns_from_stdin ".*"
  '
  [ "$status" -eq 0 ]
  [ "$output" = $'abc\ndef\nghi' ]
}

@test "read_patterns_from_stdin: separator '#|#' should split literally" {
  run bash -lc '
    source "$SSC_HOME/lib/util.sh"

    sep="$(printf "#|#")"
    printf "one#|#two#|#three" | util::read_patterns_from_stdin "#|#"
  '
  [ "$status" -eq 0 ]
  [ "$output" = $'one\ntwo\nthree' ]
}

@test "read_patterns_from_stdin: leading separator" {
  run bash -lc '
    source "$SSC_HOME/lib/util.sh"

    printf ";foo;bar" | util::read_patterns_from_stdin ";"
  '
  [ "$status" -eq 0 ]
  # leading empty → first line empty
  [ "$output" = $'\nfoo\nbar' ]
}

@test "read_patterns_from_stdin: trailing separator" {
  run bash -lc '
    source "$SSC_HOME/lib/util.sh"

    printf "foo;bar;" | util::read_patterns_from_stdin ";"
  '
  echo "output is $output"
  [ "$status" -eq 0 ]
  [ "$output" = $'foo\nbar' ]
}

@test "read_patterns_from_stdin: double separator produces empty middle entry" {
  run bash -lc '
    source "$SSC_HOME/lib/util.sh"

    printf "foo;;bar" | util::read_patterns_from_stdin ";"
  '
  [ "$status" -eq 0 ]
  [ "$output" = $'foo\n\nbar' ]
}

@test "read_patterns_from_stdin: space separator" {
  run bash -lc '
    source "$SSC_HOME/lib/util.sh"

    printf "a b c d" | util::read_patterns_from_stdin " "
  '
  [ "$status" -eq 0 ]
  [ "$output" = $'a\nb\nc\nd' ]
}

@test "read_patterns_from_stdin: tab separator" {
  run bash -lc '
    source "$SSC_HOME/lib/util.sh"
    sep="$(printf "\t")"

    printf "x\ty\tz" | util::read_patterns_from_stdin "$sep"
  '
  [ "$status" -eq 0 ]
  [ "$output" = $'x\ny\nz' ]
}

@test "read_patterns_from_stdin: mixed tokens with '#' separator" {
  run bash -lc '
    source "$SSC_HOME/lib/util.sh"

    printf "foo#bar#123#_x_#αβ" | util::read_patterns_from_stdin "#"
  '
  [ "$status" -eq 0 ]
  [ "$output" = $'foo\nbar\n123\n_x_\nαβ' ]
}

@test "read_patterns_from_stdin: separator '+'" {
  run bash -lc '
    source "$SSC_HOME/lib/util.sh"

    printf "a+b+c" | util::read_patterns_from_stdin "+"
  '
  [ "$status" -eq 0 ]
  [ "$output" = $'a\nb\nc' ]
}

@test "read_patterns_from_stdin: reject TTY" {
  run bash -lc '
    source "$SSC_HOME/lib/util.sh"
    util::read_patterns_from_stdin 2>/dev/null
  '
  [ "$status" -eq 2 ]
}
