#!/usr/bin/env bash
# Reproducible mocked-Slurm benchmark for queue hot paths.
set -Eeuo pipefail
IFS=$'\n\t'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNS="${BENCH_RUNS:-3}"
SIZES="${BENCH_SIZES:-10 100 1000 5000 10000}"
TIMEFORMAT='%R'

BENCH_TMP="$(mktemp -d)"
trap 'rm -rf "$BENCH_TMP"' EXIT

MOCK_BIN="$BENCH_TMP/bin"
BENCH_DIR="$BENCH_TMP/workdir"
CONFIG_HOME="$BENCH_TMP/config"
mkdir -p "$MOCK_BIN" "$BENCH_DIR" "$CONFIG_HOME/smartslurmcommands"
BENCH_DIR="$(cd "$BENCH_DIR" && pwd -P)"

printf '%s\n' '#SBATCH --job-name=job_000001' > "$BENCH_DIR/job.sh"

cat > "$MOCK_BIN/squeue" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '1\n' >> "$BENCH_SQUEUE_COUNT"
header=true
state=""
job_ids=""
format=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h) header=false; shift ;;
    -o) format="$2"; shift 2 ;;
    -u|--user) shift 2 ;;
    -t) state="$2"; shift 2 ;;
    -j|--jobs) job_ids="$2"; shift 2 ;;
    --me) shift ;;
    *) shift ;;
  esac
done
awk -F'|' -v state="$state" -v ids="$job_ids" -v header="$header" \
  -v format="$format" -v dependencies="${BENCH_DEPENDENCIES:-false}" '
  BEGIN {
    if (ids != "") {
      n=split(ids, requested, ",")
      for (i=1; i<=n; i++) wanted[requested[i]]=1
    }
    if (header == "true") print "JOBID|NAME|STATE|WORKDIR|ELAPSED|START|REASON|PARTITION"
  }
  (state == "" || toupper($3) == toupper(state)) &&
  (ids == "" || $1 in wanted) {
    if (format ~ /%E/) {
      dependency="(null)"
      if (dependencies == "true") {
        if ($1 == "100002") dependency="afterok:100001"
        else if ($1 == "100003") dependency="afterany:100001"
        else if ($1 == "100004") dependency="afterok:100002"
      }
      print $0 "|" dependency
    } else print
  }
' "$BENCH_ROWS"
EOF

cat > "$MOCK_BIN/scontrol" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '1\n' >> "$BENCH_SCONTROL_COUNT"
jid="${@: -1}"
dependency="(null)"
if [[ "${BENCH_DEPENDENCIES:-false}" == "true" ]]; then
  case "$jid" in
    100002) dependency="afterok:100001" ;;
    100003) dependency="afterany:100001" ;;
    100004) dependency="afterok:100002" ;;
  esac
fi
printf 'JobId=%s JobName=mock Dependency=%s\n' "$jid" "$dependency"
EOF

cat > "$MOCK_BIN/scancel" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '1\n' >> "$BENCH_SCANCEL_COUNT"
EOF
chmod +x "$MOCK_BIN/squeue" "$MOCK_BIN/scontrol" "$MOCK_BIN/scancel"

export PATH="$MOCK_BIN:$PATH"
export SSC_HOME="$ROOT"
export XDG_CONFIG_HOME="$CONFIG_HOME"
export BENCH_SQUEUE_COUNT="$BENCH_TMP/squeue.count"
export BENCH_SCONTROL_COUNT="$BENCH_TMP/scontrol.count"
export BENCH_SCANCEL_COUNT="$BENCH_TMP/scancel.count"
export BENCH_DIR

count_lines() {
  local file="$1"
  [[ -f "$file" ]] || { printf '0\n'; return; }
  wc -l < "$file" | tr -d ' '
}

generate_rows() {
  local count="$1"
  export BENCH_ROWS="$BENCH_TMP/rows.$count"
  awk -v count="$count" -v workdir="$BENCH_DIR" 'BEGIN {
    states[0]="RUNNING"; states[1]="PENDING"; states[2]="RUNNING"; states[3]="FAILED"
    parts[0]="cpu"; parts[1]="gpu"; parts[2]="long"
    for (i=1; i<=count; i++) {
      id=100000+i
      state=states[i%4]
      dir=(i%5==0 ? workdir : "/work/project" (i%20))
      elapsed=(i%2==0 ? "2-03:04:05" : "00:12:34")
      start=(state=="PENDING" ? "N/A" : sprintf("2026-01-%02dT%02d:%02d:00", 1+(i%28), i%24, i%60))
      reason=(state=="PENDING" ? (i%2 ? "(Dependency)" : "(Priority)") : "node[1-2]")
      printf "%d|job_%06d|%s|%s|%s|%s|%s|%s\n", id, i, state, dir, elapsed, start, reason, parts[i%3]
    }
  }' > "$BENCH_ROWS"
}

set_command() {
  local scenario="$1"
  export BENCH_DEPENDENCIES=false
  export SSC_SMARTCANCEL_INCLUDE_DEPENDENTS=true
  case "$scenario" in
    smartqueue_name) CMD=("$ROOT/cmd/smartqueue/smartqueue.sh" --contains job_00) ;;
    smartqueue_combined) CMD=("$ROOT/cmd/smartqueue/smartqueue.sh" --regex '^job_0.*[02468]$' --partition gpu --state running --older-than 1h) ;;
    smartqueue_directory) CMD=("$ROOT/cmd/smartqueue/smartqueue.sh" --dir "$BENCH_DIR" --state running) ;;
    smartqueue_latest) CMD=("$ROOT/cmd/smartqueue/smartqueue.sh" --dir "$BENCH_DIR" --latest) ;;
    mqpwd_combined) CMD=("$ROOT/cmd/mqpwd/mqpwd.sh" --dir "$BENCH_DIR" --regex '^job_' --state running --older-than 1h) ;;
    smartcancel_dry_run)
      export SSC_SMARTCANCEL_INCLUDE_DEPENDENTS=false
      CMD=("$ROOT/cmd/smartcancel/smartcancel.sh" --regex '^job_00000[1-5]$' --dry-run)
      ;;
    smartcancel_large_set)
      export SSC_SMARTCANCEL_INCLUDE_DEPENDENTS=false
      CMD=("$ROOT/cmd/smartcancel/smartcancel.sh" --contains job_ --dry-run)
      ;;
    smartcancel_dependents)
      export BENCH_DEPENDENCIES=true
      CMD=("$ROOT/cmd/smartcancel/smartcancel.sh" --name job_000001 --dry-run)
      ;;
    *) printf 'unknown scenario: %s\n' "$scenario" >&2; exit 2 ;;
  esac
}

measure() {
  local scenario="$1" count="$2" run timing median
  local times_file="$BENCH_TMP/times"
  : > "$times_file"
  for ((run=1; run<=RUNS; run++)); do
    : > "$BENCH_SQUEUE_COUNT"
    : > "$BENCH_SCONTROL_COUNT"
    : > "$BENCH_SCANCEL_COUNT"
    set_command "$scenario"
    timing="$BENCH_TMP/time"
    { time "${CMD[@]}" >/dev/null 2>/dev/null; } 2> "$timing"
    awk 'NF {print $NF; exit}' "$timing" >> "$times_file"
  done
  median="$(sort -n "$times_file" | awk '{a[NR]=$1} END {print a[int((NR+1)/2)]}')"
  printf '%s,%s,%s,%s,%s,%s\n' \
    "$scenario" "$count" "$median" \
    "$(count_lines "$BENCH_SQUEUE_COUNT")" \
    "$(count_lines "$BENCH_SCONTROL_COUNT")" \
    "$(count_lines "$BENCH_SCANCEL_COUNT")"
}

printf 'scenario,jobs,median_seconds,squeue_calls,scontrol_calls,scancel_calls\n'
IFS=' ' read -r -a SIZE_ARRAY <<< "$SIZES"
for count in "${SIZE_ARRAY[@]}"; do
  generate_rows "$count"
  for scenario in \
    smartqueue_name smartqueue_combined smartqueue_directory smartqueue_latest \
    mqpwd_combined smartcancel_dry_run smartcancel_large_set; do
    measure "$scenario" "$count"
  done
  # The baseline dependency walk is intentionally expensive; keep the default
  # full benchmark practical while still exposing its scaling.
  if ((count <= 1000)); then
    measure smartcancel_dependents "$count"
  fi
done
