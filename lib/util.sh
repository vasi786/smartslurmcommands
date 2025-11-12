#!/usr/bin/env bash

# Convert Slurm elapsed (%M) to seconds.
# Supports: D-HH:MM:SS | HH:MM:SS | MM:SS | "0:00" | "N/A" | "-"
time::elapsed_to_seconds() {
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
time::older_than() {
  local elapsed="$1" thresh="$2"
  local es ts unit num
  es="$(time::elapsed_to_seconds "$elapsed")"

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

# Generic: keep rows whose field f matches any value from the first input.
# Usage:
#   printf '%s\n' a b | util::filter_by_field 2 <<<"1|a|X"$'\n'"2|c|Y"
#   -> 1|a|X
util::filter_by_field() {
  local field="${1:?need field number}"; shift
  # If no values provided, just pass through
  [[ $# -gt 0 ]] || { cat; return 0; }
  awk -F'|' -v f="$field" '
  NR==FNR { set[$1]=1; next }    # First input: the value set (one per line)
  ($f in set)                     # Second input: candidates from stdin
  ' <(printf '%s\n' "$@") -
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
  util::filter_by_field 2 "$@"
}

# Convenience: filter candidates (stdin) by job names found in dir’s *.sh (#SBATCH --job-name)
util::apply_this_dir_filter() {
  local dir="${1:?dir}"
  mapfile -t _names < <(util::job_names_from_dir "$dir")
  [[ ${#_names[@]} -gt 0 ]] || { : > /dev/stdout; return 0; }
  util::filter_by_field "${_names[@]}"
}

