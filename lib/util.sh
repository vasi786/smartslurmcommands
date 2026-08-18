#!/usr/bin/env bash
# Convert Slurm elapsed (%M) to seconds.
# Supports: D-HH:MM:SS | HH:MM:SS | MM:SS | "0:00" | "N/A" | "-"
util::elapsed_to_seconds() {
  local e="$1"
  local output_var="${2:-}"
  local total=0
  if [[ -z "$e" || "$e" == "N/A" || "$e" == "-" ]]; then
    if [[ -n "$output_var" ]]; then
      printf -v "$output_var" '%d' 0
    else
      printf '0\n'
    fi
    return 0
  fi

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
  total=$(( d*86400 + h*3600 + m*60 + s ))
  if [[ -n "$output_var" ]]; then
    printf -v "$output_var" '%d' "$total"
  else
    printf '%d\n' "$total"
  fi
}

# Convert a user-facing duration such as 30m, 2h, 3d, or 600 to seconds.
util::duration_to_seconds() {
  local duration="$1"
  local output_var="${2:-}"
  [[ "$duration" =~ ^[0-9]+[smhd]?$ ]] || {
    printf 'error: invalid duration: %s\n' "$duration" >&2
    return 2
  }

  local unit="${duration: -1}" number total
  case "$unit" in
    s|m|h|d) number="${duration%?}" ;;
    *) number="$duration"; unit="s" ;;
  esac
  number=$((10#$number))

  case "$unit" in
    s) total=$number ;;
    m) total=$((number * 60)) ;;
    h) total=$((number * 3600)) ;;
    d) total=$((number * 86400)) ;;
  esac

  if [[ -n "$output_var" ]]; then
    printf -v "$output_var" '%d' "$total"
  else
    printf '%d\n' "$total"
  fi
}

# Return 0 (true) if elapsed > threshold (e.g., 10m, 2h, 3d, 600s)
util::older_than() {
  local elapsed="$1" thresh="$2"
  local es ts
  util::elapsed_to_seconds "$elapsed" es || return
  util::duration_to_seconds "$thresh" ts || return

  [[ "$es" -gt "$ts" ]]
}

# current_user helper (unchanged)
current_user() { id -un 2>/dev/null || echo "${USER:-unknown}"; }

# Pick the latest line deterministically.
# Use StartTime when every candidate has one; if any candidate lacks StartTime
# (as pending jobs often do), use the highest numeric JobID for the whole set.
util::pick_latest_line() {
  awk -F'|' '
    BEGIN { count=0; all_have_start=1; bestid=-1; bestS="" }
    {
      count++
      id=$1 + 0
      start=$6
      line[count]=$0
      ids[count]=id
      starts[count]=start
      if (start !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}/) all_have_start=0
    }
    END {
      if (!count) exit
      best=1
      for (i=2; i<=count; i++) {
        if (all_have_start) {
          if (starts[i] > starts[best] ||
              (starts[i] == starts[best] && ids[i] > ids[best])) best=i
        } else if (ids[i] > ids[best]) {
          best=i
        }
      }
      print line[best]
    }
  '
}

# Keep rows whose elapsed-time field is greater than THRESHOLD. The complete
# input row is emitted unchanged so later filters retain every Slurm field.
util::filter_candidates_older_than() {
  local threshold="${1:?need threshold}"
  [[ "$threshold" =~ ^[0-9]+[smhd]?$ ]] || {
    printf 'error: invalid duration: %s\n' "$threshold" >&2
    return 2
  }

  awk -F'|' -v threshold="$threshold" '
    function duration_seconds(value, unit, number) {
      unit=substr(value, length(value), 1)
      if (unit ~ /^[smhd]$/) number=substr(value, 1, length(value)-1) + 0
      else { unit="s"; number=value + 0 }
      if (unit == "d") return number * 86400
      if (unit == "h") return number * 3600
      if (unit == "m") return number * 60
      return number
    }
    function elapsed_seconds(value, day_parts, time_parts, days, hours, minutes, seconds, n) {
      days=hours=minutes=seconds=0
      n=split(value, day_parts, "-")
      if (n == 2) { days=day_parts[1] + 0; value=day_parts[2] }
      n=split(value, time_parts, ":")
      if (n == 3) { hours=time_parts[1]+0; minutes=time_parts[2]+0; seconds=time_parts[3]+0 }
      else if (n == 2) { minutes=time_parts[1]+0; seconds=time_parts[2]+0 }
      return days*86400 + hours*3600 + minutes*60 + seconds
    }
    BEGIN { limit=duration_seconds(threshold) }
    NF && elapsed_seconds($5) > limit { print }
  '
}

# Keep complete records whose Slurm duration in FIELD is strictly less than
# THRESHOLD. Non-numeric values such as NOT_SET, UNLIMITED, N/A, and INVALID
# are excluded so an unknown duration is never treated as zero.
util::filter_candidates_by_time_less_than() {
  local field="${1:?need field number}"
  local threshold="${2:?need threshold}"
  local limit
  util::duration_to_seconds "$threshold" limit || return

  local line value seconds
  local -a fields=()
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    IFS='|' read -r -a fields <<<"$line"
    value="${fields[field-1]:-}"
    [[ "$value" =~ ^(([0-9]+-)?[0-9]+:[0-9]{2}:[0-9]{2}|[0-9]+:[0-9]{2})$ ]] || continue
    util::elapsed_to_seconds "$value" seconds
    if (( seconds < limit )); then
      printf '%s\n' "$line"
    fi
  done
}

util::filter_candidates_younger_than() {
  util::filter_candidates_by_time_less_than 5 "${1:?need threshold}"
}

util::filter_candidates_time_left() {
  util::filter_candidates_by_time_less_than 9 "${1:?need threshold}"
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

# Keep rows whose FIELD contains ANY of the provided substrings (literal, non-regex).
# Usage:
#   printf '%s\n' "1|alpha" "2|beta" \
#     | util::filter_candidates_by_field_contains 2 foo bar
util::filter_candidates_by_field_contains() {
  local field="${1:?need field number}"; shift
  if [ "$#" -eq 0 ]; then cat; return 0; fi

  awk -F'|' -v f="$field" '
    NR==FNR { pats[++np] = $1; next }
    {
      for (i = 1; i <= np; i++) {
        if (index($f, pats[i]) > 0) { print; break }
      }
    }
  ' <(printf '%s\n' "$@") -
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
  local absdir
  if command -v realpath >/dev/null 2>&1; then
    absdir="$(realpath "$dir")"
  else
    absdir="$(cd "$dir" && pwd -P)"
  fi

  local -a _names=()
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
  local sep="${1:-$'\n'}"
  local buf

  # Require non-TTY stdin
  if [[ -t 0 ]]; then
    echo "error: expecting stdin but got TTY" >&2
    return 2
  fi

  buf="$(cat)"
  [[ -n "$buf" ]] || { echo "error: no patterns received on stdin" >&2; return 2; }

  # Default: newline separator → pass through as-is
  if [[ "$sep" == $'\n' ]]; then
    printf '%s\n' "$buf"
    return 0
  fi

  # Guard against empty separator (infinite loop)
  if [[ -z "$sep" ]]; then
    echo "error: empty separator passed to read_patterns_from_stdin" >&2
    return 2
  fi

  # Pure Bash split on a literal substring $sep
  local rest="$buf"
  local out="" chunk

  while [[ "$rest" == *"$sep"* ]]; do
    chunk="${rest%%"$sep"*}"     # part before first sep
    out+="$chunk"$'\n'
    rest="${rest#*"$sep"}"       # strip up to and including first sep
  done
  out+="$rest"

  printf '%s\n' "$out"
}
