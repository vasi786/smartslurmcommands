#!/usr/bin/env bash
# util.sh - Util library module
# # Convert Slurm elapsed "%M" (MM:SS or HH:MM:SS) to seconds
time::elapsed_to_seconds() {
  local e="$1" IFS=':'
  local a b c
  read -r a b c <<<"$e"
  if [[ -n "$c" ]]; then
    echo $((10#$a*3600 + 10#$b*60 + 10#$c))
  else
    echo $((10#$a*60 + 10#$b))
  fi
}

# Return 0 if elapsed (like 12:34) is strictly greater than threshold (like 10m, 2h, 45s)
time::older_than() {
  local elapsed="$1" thresh="$2"
  local es ts
  es="$(time::elapsed_to_seconds "$elapsed")"

  # reuse your existing duration parser if you have one; simple inline parser here:
  case "${thresh: -1}" in
    s) ts="${thresh%?}";;
    m) ts=$(( ${thresh%?} * 60 ));;
    h) ts=$(( ${thresh%?} * 3600 ));;
    *) ts="${thresh}";;  # assume seconds if no unit
  esac

  [[ "$es" -gt "$ts" ]]
}

