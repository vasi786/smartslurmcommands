#!/usr/bin/env bash
# smartcancel - smarter wrapper around scancel focused on dir/name workflows.
set -Eeuo pipefail
IFS=$'\n\t'

# --- Libs (keep order: core -> cfg -> colors/log -> io/util -> slurm)
SSC_HOME="${SSC_HOME:-"$(cd "$(dirname "$0")/../.." && pwd)"}"
source "$SSC_HOME/lib/core.sh"
source "$SSC_HOME/lib/cfg.sh";      cfg::load
# source "$SSC_HOME/lib/colors.sh";   color::setup "$(cfg::get color auto)"
# source "$SSC_HOME/lib/log.sh";      LOG_LEVEL="$(cfg::get log_level info)"
source "$SSC_HOME/lib/io.sh"
source "$SSC_HOME/lib/util.sh"
# source "$SSC_HOME/lib/args.sh"
source "$SSC_HOME/lib/slurm.sh"
source "$SSC_HOME/lib/ui.sh"

usage() {
  cat <<'EOF'
Usage: smartcancel [FILTERS] [BEHAVIOR]

Filters (combine as needed):
  --this-dir                 Cancel jobs whose WorkDir == $PWD (fallback: name == basename($PWD))
  --dir PATH                 Cancel jobs whose WorkDir == PATH (fallback: name == basename(PATH))
  --name NAME                Exact job name match
  --contains SUBSTR          Job name contains substring
  --contains-from-stdin      with this option, smartcancel accept's patterns from stdin (ex: somecommand |smartcancel --contains-from-stdin --dry-run)
  --older-than DUR           Only jobs with elapsed time > DUR (e.g., 10m, 2h)
  --state STATE              Only jobs in this Slurm state (e.g., RUNNING, PENDING, DEPENDENCY) - non-case-sensitive
  --partition NAME[,NAME...]   Only jobs in these Slurm partitions
  --latest                   Pick only the latest matching job (by StartTime or JobID)

Dependency handling (deprecated):
  --with-dependents          Also cancel jobs that depend on selected jobs (reverse dependency walk)

Behavior:
  --dry-run                  Show what would be cancelled
  --yes                      Do not prompt
  -h, --help                 Show this help
EOF
}

DEFAULT_REASON="$(cfg::get SMARTCANCEL_DEFAULT_REASON "")"

# --- Parse args
THIS_DIR=false
DIR_FILTER=""
NAME_EQ=""
NAME_CONTAINS=""
OLDER_THAN=""
STATE_FILTER=""
PARTITION_FILTER=""
# Reason filter is only used when --state dependency is supplied
REASON_FILTER=""
LATEST=false
DRY=false
YES=false
REASON="$DEFAULT_REASON"
CONTAINS_FROM_STDIN=false
SELECTOR_COUNT=0   # counts “narrowing” selectors
declare -a CONTAINS_PATTERNS=()


while [[ $# -gt 0 ]]; do
  case "$1" in
    --this-dir) THIS_DIR=true; SELECTOR_COUNT=$((SELECTOR_COUNT+1));  shift ;;
    --dir) DIR_FILTER="$2"; SELECTOR_COUNT=$((SELECTOR_COUNT+1));shift 2 ;;
    --name) NAME_EQ="$2"; SELECTOR_COUNT=$((SELECTOR_COUNT+1));shift 2 ;;
    --contains) NAME_CONTAINS="$2"; SELECTOR_COUNT=$((SELECTOR_COUNT+1));shift 2 ;;
    --contains-from-stdin) CONTAINS_FROM_STDIN=true; SELECTOR_COUNT=$((SELECTOR_COUNT+1));shift ;;
    --older-than) OLDER_THAN="$2"; SELECTOR_COUNT=$((SELECTOR_COUNT+1));shift 2 ;;
    --latest) LATEST=true; SELECTOR_COUNT=$((SELECTOR_COUNT+1));shift ;;
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
    # --with-dependents) WITH_DEPS=true; shift ;;
    # --reason) REASON="$2"; shift 2 ;;
    --dry-run) DRY=true; shift ;;
    --yes) YES=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die 2 "Unknown argument: $1 (see --help)";;
  esac
done

if (( SELECTOR_COUNT == 0 )); then
  die 2 "Refusing to operate with no selector. Use one of: --this-dir, --dir, --name, --contains, --contains-from-stdin, --latest, --state."
fi

# If user asked to read patterns from stdin, do it now
if $CONTAINS_FROM_STDIN; then
  if [[ -t 0 ]]; then
    die 2 "--contains-from-stdin was given, but stdin is a TTY (no input). Pipe patterns in."
  fi
  while IFS= read -r line; do
    [[ -n "$line" ]] && CONTAINS_PATTERNS+=("$line")
  done
  if ((${#CONTAINS_PATTERNS[@]} == 0)); then
    die 2 "--contains-from-stdin received no patterns on stdin."
  fi
fi


# Return lines: JobID|JobName|State|WorkDir|Elapsed|StartTime|Reason for a user (default: current)
SQUEUE_CACHE="$(slurm::squeue_lines "$STATE_FILTER")"
CANDIDATES="$SQUEUE_CACHE"

if $THIS_DIR || [[ -n "$DIR_FILTER" ]]; then
  dir="${DIR_FILTER:-$PWD}"
  [[ -d "$dir" ]] || die 2 "Directory not found: $dir"

  # Extract job names from sbatch scripts in that dir
  mapfile -t _names < <(slurm::job_names_from_dir "$dir")
  [[ ${#_names[@]} -gt 0 ]] || die 0 "No #SBATCH --job-name found in *.sh under: $dir"

  # Keep only lines whose JobName ($2) is in _names
  # Use AWK "two-file trick": first input builds a set from names, second filters CANDIDATES
  CANDIDATES="$(
    awk -F'|' 'NR==FNR { set[$1]=1; next } set[$2] { print $0 }' \
      <(printf '%s\n' "${_names[@]}") \
      <(printf '%s\n' "$CANDIDATES")
  )"
fi

# Name filters
if [[ -n "$NAME_EQ" ]]; then
  CANDIDATES="$(awk -F'|' -v n="$NAME_EQ" '($2 == n)' <<<"$CANDIDATES")"
fi
if [[ -n "$NAME_CONTAINS" ]]; then
  CANDIDATES="$(awk -F'|' -v s="$NAME_CONTAINS" 'index($2,s)>0' <<<"$CANDIDATES")"
fi
# Multiple contains patterns from stdin
if ((${#CONTAINS_PATTERNS[@]} > 0)); then
  CANDIDATES="$(
    awk -F'|' '
      NR==FNR { pat[$0]=1; next }
      {
        for (p in pat) if (index($2,p)>0) { print; next }
      }
    ' <(printf '%s\n' "${CONTAINS_PATTERNS[@]}") <(printf '%s\n' "$CANDIDATES")
  )"
fi
if [[ -n "$PARTITION_FILTER" ]]; then
  # Build a regex like ^(genoa|rome)$ and match after stripping any trailing '*'
  part_re="^($(printf '%s' "$PARTITION_FILTER" | sed 's/,/|/g'))$"
  CANDIDATES="$(
    awk -F'|' -v re="$part_re" '
      {
        p=$8
        sub(/\*$/,"",p)      # squeue sometimes marks default partition with *
        if (p ~ re) print
      }
    ' <<<"$CANDIDATES"
  )"
fi

# Time filter in pure Bash (no awk math needed)
if [[ -n "$OLDER_THAN" ]]; then
  filtered=""
  while IFS='|' read -r jid jname state wdir elapsed start; do
    [[ -z "$jid" ]] && continue
    if time::older_than "$elapsed" "$OLDER_THAN"; then
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

# Build ID list
TARGET_IDS="$(cut -d'|' -f1 <<<"$CANDIDATES" | sed '/^$/d' | sort -u)"
if [[ -n "$TARGET_IDS" ]]; then
  before_count="$(wc -l <<<"$TARGET_IDS" | tr -d ' ')"
  TARGET_IDS="$(expand_with_dependents "$SQUEUE_CACHE" "$TARGET_IDS")"
  after_count="$(wc -l <<<"$TARGET_IDS" | tr -d ' ')"
  if (( after_count > before_count )); then
    echo "Info: also cancelling $((after_count - before_count)) dependent job(s)." >&2
  fi
fi

# --- Act
if [[ -z "$TARGET_IDS" ]]; then
  log_info "No matching jobs."
  exit 0
fi

# Bold header (using ANSI codes)
echo -e "\e[1mJobs to cancel\e[0m"

# Pretty table with Reason (field 7)
awk -F'|' '
BEGIN {
  printf("%-12s %-20s %-10s %-25s %-s\n", "JobID", "JobName", "State", "Reason", "WorkDir")
}
{
  printf("%-12s %-20s %-10s %-25s %-s\n", $1, $2, $3, $7, $4)
}' <<<"$CANDIDATES"

if $DRY; then
  echo
  echo "Dry-run (no changes):"
  while read -r id; do
    [[ -n "$id" ]] && echo "scancel ${REASON:+--reason \"$REASON\"} $id"
  done <<< "$TARGET_IDS"
  exit 0
fi

if ! $YES; then
  echo
  confirm "Cancel $(wc -l <<<"$TARGET_IDS" | tr -d ' ') job(s)?" || { echo "Aborted."; exit 1; }
fi

# Execute
while read -r id; do
  [[ -z "$id" ]] && continue
  if [[ -n "$REASON" ]]; then
    scancel --reason "$REASON" "$id" || log_warn "Failed to cancel $id"
  else
    scancel "$id" || log_warn "Failed to cancel $id"
  fi
done <<< "$TARGET_IDS"

log_info "Done."
