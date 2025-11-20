#!/usr/bin/env bash
# Convert Slurm elapsed (%M) to seconds.
# Supports: D-HH:MM:SS | HH:MM:SS | MM:SS | "0:00" | "N/A" | "-"
util::elapsed_to_seconds() {
  local e="$1"
  [[ -z "$e" || "$e" == "N/A" || "$e" == "-" ]] && { echo 0; return; }

  local d=0 h=0 m=0 s=0 rest
  if [[ "$e" == *-*:*:* ]]; then
    IFS='-' read -r d rest <<<"$e"
    IFS=':' read -r h m s <<<"$rest"
  elif [[ "$e" == *:*:* ]]; then
    IFS=':' read -r h m s <<<"$e"
  else
    IFS=':' read -r m s <<<"$e"
  fi
  # force base-10 to ignore leading zeros
  d=$((10#$d)); h=$((10#$h)); m=$((10#$m)); s=$((10#$s))
  echo $(( d*86400 + h*3600 + m*60 + s ))
}

# Return 0 (true) if elapsed > threshold (e.g., 10m, 2h, 3d, 600s)
util::older_than() {
  local elapsed="$1" thresh="$2"
  local es ts unit num
  es="$(util::elapsed_to_seconds "$elapsed")"

  unit="${thresh: -1}"
  case "$unit" in
    s|m|h|d) num="${thresh%?}";;
    *)       num="$thresh"; unit="s";;   # bare number = seconds
  esac
  # coerce to base-10
  num=$((10#$num))

  case "$unit" in
    s) ts=$(( num ));;
    m) ts=$(( num * 60 ));;
    h) ts=$(( num * 3600 ));;
    d) ts=$(( num * 86400 ));;
  esac

  [[ "$es" -gt "$ts" ]]
}

# current_user helper (unchanged)
current_user() { id -un 2>/dev/null || echo "${USER:-unknown}"; }

# Pick the "latest" line by StartTime (field 6), fallback to highest JobID
util::pick_latest_line() {
  awk -F'|' '
    BEGIN { bestid=0; bestS=""; have=0 }
    {
      id=$1; S=$6;
      if (S ~ /[0-9]/) {
        if (!have || S > bestS) { bestS=S; bestid=id; best=$0; have=1 }
      } else {
        if (!have || id+0 > bestid+0) { bestid=id; best=$0; have=1 }
      }
    }
    END { if (have) print best }
  '
}

# Generic: keep rows whose field f matches any value from the first input.
# Usage:
#   printf '%s\n' a b | util::filter_candidates_by_field_values 2 <<<"1|a|X"$'\n'"2|c|Y"
#   -> 1|a|X
util::filter_candidates_by_field_values() {
  local field="${1:?need field number}"; shift
  # If no values provided, just pass through
  [[ $# -gt 0 ]] || { cat; return 0; }
  awk -F'|' -v f="$field" '
  NR==FNR { set[$1]=1; next }    # First input: the value set (one per line)
  ($f in set)                     # Second input: candidates from stdin
  ' <(printf '%s\n' "$@") -
}

# Keep rows whose FIELD contains ANY of the provided substrings.
# Usage:
#   printf "%s\n" "1|alpha" "2|beta" "3|gamma" | util::filter_candidates_by_field_contains 2 ta mm
#   -> "2|beta" and "3|gamma"

util::filter_candidates_by_field_contains() {
  local field="${1:?need field number}"; shift
  if [ "$#" -eq 0 ]; then cat; return 0; fi

  # Build an alternation regex from the args, escaping regex metachars
  local pattern="" term esc
  for term in "$@"; do
    esc=$(printf '%s' "$term" | sed -e 's/[][^$.*/\\?+(){}|]/\\&/g')
    pattern="${pattern:+$pattern|}$esc"
  done

  awk -F'|' -v f="$field" -v pat="$pattern" '
    $f ~ pat { print }
  '
}

util::filter_candidates_by_field_regex() {
  local field="${1:?need field number}"; shift

  # No patterns → pass through
  if [ "$#" -eq 0 ]; then cat; return 0; fi

  local pattern="" term
  for term in "$@"; do
    [[ -z "$term" ]] && continue
    pattern="${pattern:+$pattern|}($term)"
  done

  [[ -z "$pattern" ]] && { cat; return 0; }

  awk -F'|' -v f="$field" -v pat="$pattern" '
    $f ~ pat { print }
  '
}

# Return newline-separated job names declared in #SBATCH directives within *.sh in DIR.
# Handles:
#   #SBATCH --job-name=NAME
#   #SBATCH --job-name NAME
#   #SBATCH --job-name="name with spaces"
# Extract job names from #SBATCH in top-level *.sh files of a directory.
util::job_names_from_dir() {
  local dir="${1:-$PWD}"
  [[ -d "$dir" ]] || { echo "error: directory not found: $dir" >&2; return 2; }

  mapfile -t files < <(find "$dir" -maxdepth 1 -type f -name "*.sh" 2>/dev/null | sort)
  [[ ${#files[@]} -gt 0 ]] || return 0  # no scripts -> no names

  # Grep SBATCH job-name lines and extract the value (handles = / space and quotes)
  grep -hE '^[[:space:]]*#SBATCH[[:space:]]+--job-name(=|[[:space:]])' "${files[@]}" 2>/dev/null \
  | sed -E 's/^[[:space:]]*#SBATCH[[:space:]]+--job-name[[:space:]]*=?[[:space:]]*//; s/[[:space:]]+$//' \
  | sed -E 's/^"(.*)"$/\1/; s/'"'"'(.*)'"'"'$/\1/' \
  | awk 'NF' \
  | sort -u
}

# Given names[] and pipe-delimited candidates, keep rows where JobName ($2) ∈ names.
# Reads candidates from stdin; prints filtered rows.
util::filter_candidates_by_job_names() {
  util::filter_candidates_by_field_values 2 "$@"
}
util::filter_candidates_by_partition() {
  local parts="${1:-}"
  [[ -n "$parts" ]] || { cat; return 0; }

  # Convert comma-separated list → regex (e.g., genoa,rome → ^(genoa|rome)$)
  local part_re
  part_re="^($(printf '%s' "$parts" | sed 's/,/|/g'))$"

  awk -F'|' -v re="$part_re" '
    {
      p = $8
      sub(/\*$/, "", p)   # remove trailing * (default partition mark)
      if (p ~ re) print
    }
  '
}
util::apply_dir_filter_with_fallback() {
  local dir="${1:?}"
  local candidates; candidates="$(cat)"
  absdir=$(realpath "$dir")

  mapfile -t _names < <(util::job_names_from_dir "$dir")

  # Subset A: by names (if any)
  local subset_names=""
  if [[ ${#_names[@]} -gt 0 ]]; then
    subset_names="$(printf '%s\n' "$candidates" \
      | util::filter_candidates_by_job_names "${_names[@]}")"
  fi

  # Subset B: by WorkDir==absdir
  local subset_dir=""
  subset_dir="$(awk -F'|' -v d="$absdir" '$4 == d' <<<"$candidates")"

  # Union (dedupe by full line)
  printf '%s\n%s\n' "$subset_names" "$subset_dir" \
  | awk 'NF' \
  | awk '!seen[$0]++'
}
util::version() {
    cat "$SSC_HOME/VERSION"
}
util::read_patterns_from_stdin() {
  # Read patterns from stdin.
  # Default separator = newline.
  # If user provides a custom separator, e.g. --sep ';' or '|', then
  # this function splits using that instead.
  #
  # Usage:
  #   mapfile -t arr < <(util::read_patterns_from_stdin "$SEP")
  #
  # If stdin is a TTY → error.
  # If no patterns → error unless caller handles it.
  local sep="${1:-$'\n'}"   # default = newline
  local buf

  # stdin must not be a tty
  if [[ -t 0 ]]; then
    echo "error: expecting stdin but got TTY" >&2
    return 2
  fi

  # read whole stdin into buf
  buf="$(cat)"
  [[ -n "$buf" ]] || { echo "error: no patterns received on stdin" >&2; return 2; }

  # If separator is newline → simple passthrough
  if [[ "$sep" == $'\n' ]]; then
    printf "%s\n" "$buf"
    return 0
  fi

  # Otherwise split manually
  # Replace ALL occurrences of $sep with newline
  # We escape the separator properly for sed
  local esc_sep
  esc_sep=$(printf '%s' "$sep" | sed -E 's/[][\.^$*+?(){}|]/\\&/g')

  printf "%s" "$buf" \
    | sed "s/${esc_sep}/\\
/g"
}
