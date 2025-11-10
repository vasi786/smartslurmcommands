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

