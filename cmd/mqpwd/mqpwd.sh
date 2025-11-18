#!/usr/bin/env bash
# mqpwd — list jobs associated with sbatch scripts OR working directory with filters
set -Eeuo pipefail
IFS=$'\n\t'

SSC_HOME="${SSC_HOME:-"$(cd "$(dirname "$0")/../.." && pwd)"}"
source "$SSC_HOME/lib/core.sh"
source "$SSC_HOME/lib/slurm.sh"
source "$SSC_HOME/lib/util.sh"

usage() {
  cat <<'EOF'
mqpwd - List jobs associated with sbatch scripts or working directory

Usage:
  mqpwd
      List jobs whose SBATCH --job-name appears in *.sh inside the current
      directory, or whose WorkDir matches the current path.

  Filters (combine as needed):
    --dir PATH                 show jobs whose WorkDir == PATH (fallback: name == basename(PATH))
    --name NAME                Exact job name match
    --contains SUBSTR          Job name contains substring
    --older-than DUR           Only jobs with elapsed time > DUR (e.g., 10m, 2h)
    --state STATE              Only jobs in this Slurm state (e.g., RUNNING, PENDING, DEPENDENCY) - non-case-sensitive
    --partition NAME[,NAME...]   Only jobs in these Slurm partitions
    --latest                   Pick only the latest matching job (by StartTime or JobID)

Behavior:
  -h, --help                 Show this help
  • If the directory contains *.sh scripts with "#SBATCH --job-name", those
    job names are extracted and used to filter squeue output.

  • If no job-name lines are found, mqpwd falls back to matching jobs whose
    WorkDir exactly matches the directory.

Output:
  Matches are printed using your mq-style squeue formatting.

Examples:
  mqpwd
  mqpwd --dir ~/projects/my_sim
  mqpwd --dir /scratch/work/pex13/simR2

Notes:
  This command NEVER cancels any job — it is read-only and safe.

EOF
}

DIR_FILTER="$(pwd)"
NAME_EQ=""
NAME_CONTAINS=""
OLDER_THAN=""
STATE_FILTER=""
PARTITION_FILTER=""
REASON_FILTER=""
LATEST=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) DIR_FILTER="$2"; shift 2 ;;
    --name) NAME_EQ="$2"; shift 2 ;;
    --contains) NAME_CONTAINS="$2"; shift 2 ;;
    --older-than) OLDER_THAN="$2"; shift 2 ;;
    --latest) LATEST=true; shift ;;
    --state)
      val="$(tr '[:upper:]' '[:lower:]' <<<"$2")"; SELECTOR_COUNT=$((SELECTOR_COUNT+1));shift 2
      case "$val" in
        dependency|dep|deps)
          STATE_FILTER="PENDING"
          REASON_FILTER="Dependency"
          ;;
        pending|running|suspended|completed|cancelled|failed|timeout|node_fail|preempted|boot_fail|deadline|out_of_memory|completing|configuring|resizing|resv_del_hold|requeued|requeue_fed|requeue_hold|revoked|signaling|special_exit|stage_out|stopped)
          STATE_FILTER="$(tr '[:lower:]' '[:upper:]' <<<"$val")"
          ;;
        *)
          die 2 "Unknown state: $val"
          ;;
      esac
      ;;
    --partition) PARTITION_FILTER="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --version) util::version; exit 0 ;;
    *) die 2 "Unknown argument: $1 (see --help)";;
  esac
done

[[ -d "$DIR_FILTER" ]] || die 2 "Directory not found: $dir"

# Resolve absolute, physical path (keeps tests & matching consistent)
if command -v realpath >/dev/null 2>&1; then
  absdir="$(realpath "$DIR_FILTER")"
else
  absdir="$(cd "$DIR_FILTER" && pwd -P)"
fi

# Build a cache of this user’s jobs in our pipe format:
# %i|%j|%T|%Z|%M|%S|%R|%P  → id|name|state|workdir|elapsed|start|reason|partition
# The below directive is issued as calling the squeue_lines function without any arguments is intentional (goes to default --> all jobs and current user)
# shellcheck disable=SC2119
SQUEUE_CACHE="$(slurm::squeue_lines "$STATE_FILTER")"


# Filter by names from *.sh in dir OR by WorkDir==absdir (union, dedup)
CANDIDATES="$(printf '%s\n' "$SQUEUE_CACHE" | util::apply_dir_filter_with_fallback "$absdir")"

if [[ -z "$CANDIDATES" ]]; then
  echo "No jobs found related to: $absdir"
  exit 0
fi

if [[ -n "$NAME_EQ" ]]; then
  CANDIDATES="$(printf '%s\n' "$CANDIDATES" | util::filter_candidates_by_field_values 2 "$NAME_EQ")"
fi
if [[ -n "$NAME_CONTAINS" ]]; then
  CANDIDATES="$(printf '%s\n' "$CANDIDATES" | util::filter_candidates_by_field_contains 2 "$NAME_CONTAINS")"
fi
if [[ -n "$PARTITION_FILTER" ]]; then
  CANDIDATES="$(printf '%s\n' "$CANDIDATES" | util::filter_candidates_by_partition "$PARTITION_FILTER")"
fi
if [[ -n "$OLDER_THAN" ]]; then
  filtered=""
  while IFS='|' read -r jid jname state wdir elapsed start; do
    [[ -z "$jid" ]] && continue
    if util::older_than "$elapsed" "$OLDER_THAN"; then
      filtered+="$jid|$jname|$state|$wdir|$elapsed|$start"$'\n'
    fi
  done <<< "$CANDIDATES"
  CANDIDATES="$filtered"
fi
# Latest only
if $LATEST; then
  CANDIDATES="$(slurm::pick_latest_line <<<"$CANDIDATES")"
fi
if [[ -n "$REASON_FILTER" ]]; then
  CANDIDATES="$(awk -F'|' -v r="$REASON_FILTER" '$7 ~ r' <<<"$CANDIDATES")"
fi
# Extract job IDs and print like your `mq` alias
csv_ids="$(cut -d'|' -f1 <<<"$CANDIDATES" | sed '/^$/d' | paste -sd, -)"
if [[ -z "$csv_ids" ]]; then
  echo "No job IDs found after filtering for: $absdir"
  exit 0
fi

# Same columns as your alias:
#   %.10i %.10P  %35j %.8u %.2t  %.10M [%.10L] %.5m %.5C - %5D %R
require_cmd squeue
squeue --me -j "$csv_ids" -o "%.10i %.10P  %35j %.8u %.2t  %.10M [%.10L] %.5m %.5C - %5D %R"
