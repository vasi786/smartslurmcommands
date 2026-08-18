#!/usr/bin/env bash
# smartcancel - smarter wrapper around scancel focused on dir/name workflows.
set -Eeuo pipefail
IFS=$'\n\t'

# --- Libs (keep order: core -> cfg -> colors/log -> io/util -> slurm)
SSC_HOME="${SSC_HOME:-"$(cd "$(dirname "$0")/../.." && pwd)"}"
source "$SSC_HOME/lib/core.sh"
source "$SSC_HOME/lib/cfg.sh";      cfg::load
source "$SSC_HOME/lib/log.sh";
source "$SSC_HOME/lib/util.sh"
source "$SSC_HOME/lib/args.sh"
source "$SSC_HOME/lib/slurm.sh"
source "$SSC_HOME/lib/io.sh"

usage() {
  cat <<'EOF'
  Usage: smartcancel [FILTERS] [BEHAVIOR (optional)]

Filters (combine as needed):
  --this-dir                   Cancel jobs whose WorkDir == $PWD or fallback to the job_name found in the CWD.
  --dir PATH                   Cancel jobs whose WorkDir == PATH or fallback to the job_name found in the PATH.
  --name NAME                  Exact job name match.
  --contains SUBSTR            Job name contains substring.
  --contains-from-stdin        With this option, smartcancel accept's substring from stdin (ex: somecommand |smartcancel --contains-from-stdin --dry-run).
  --regex PATTERN              Job names with matching regex pattern will be filtered.
  --regex-from-stdin           With this option, smartcancel accept's regex patterns from stdin (ex: somecommand |smartcancel --regex-from-stdin --dry-run).
  --older-than DUR             Only jobs with elapsed time > DUR (e.g., 10m, 2h).
  --younger-than DUR           Only jobs with elapsed time < DUR (e.g., 10m, 2h).
  --time-left DUR              Only jobs with remaining time < DUR (e.g., 30m, 2h).
  --state STATE                Only jobs in this Slurm state (e.g., RUNNING, PENDING, DEPENDENCY) - non-case-sensitive. Dependency is the only excpetion which is treated as state.
  --partition NAME[,NAME...]   Only jobs in these Slurm partitions.
  --latest                     Pick the latest matching job. Uses StartTime when all
                               matches have one; otherwise falls back to JobID.

Behavior:
  --dry-run                    Show what would be cancelled.
  --force                      Do not prompt.

  Jobs that recursively depend on selected jobs are included by default. Every
  included job is shown before confirmation. Set
  smartcancel.include_dependents=false in the configuration to disable this.

Other:
  -h, --help                   Show this help.
  --version                    Shows the version of smartslurmcommands.
  --verbose                    Prints the information of at what step the code is and how many jobs did it find for the filter you passed.
  --debug                      Prints the information of at what step the code and outputs the command.
EOF
}

# --- Parse args
THIS_DIR=false
DIR_FILTER=""
NAME_EQ=""
NAME_CONTAINS=""
NAME_REGEX=""
OLDER_THAN=""
YOUNGER_THAN=""
TIME_LEFT=""
STATE_FILTER=""
PARTITION_FILTER=""
# currently reason filter is only used when --state dependency is supplied
REASON_FILTER=""
LATEST=false
DRY="$(cfg::get_bool dry_run false)"
FORCE=false
CONFIRM_ENABLED="$(cfg::get_bool confirm true)"
INCLUDE_DEPENDENTS="$(cfg::get_bool smartcancel.include_dependents true)"
CONTAINS_FROM_STDIN=false
REGEX_FROM_STDIN=false
SELECTOR_COUNT=0   # counts “narrowing” selectors
STDIN_SEP=$'\n'   # default = newline
declare -a CONTAINS_JOB_NAMES=() # will be used for contains-from-stdin, for taking the multiple inputs from the stdin and treats as part or whole job names
declare -a REGEX_PATTERNS=() # will be used for regex-from-stdin, for taking the multiple inputs from the stdin and treats as part or whole job names
SSC_LOG_LEVEL="${SSC_LOG_LEVEL:-none}"


while [[ $# -gt 0 ]]; do
  case "$1" in
    --this-dir) THIS_DIR=true; SELECTOR_COUNT=$((SELECTOR_COUNT+1));  shift ;;
    --dir) DIR_FILTER="$2"; SELECTOR_COUNT=$((SELECTOR_COUNT+1));shift 2 ;;
    --name) NAME_EQ="$2"; SELECTOR_COUNT=$((SELECTOR_COUNT+1));shift 2 ;;
    --contains) NAME_CONTAINS="$2"; SELECTOR_COUNT=$((SELECTOR_COUNT+1));shift 2 ;;
    --regex) NAME_REGEX="$2"; SELECTOR_COUNT=$((SELECTOR_COUNT+1));shift 2 ;;
    --contains-from-stdin) CONTAINS_FROM_STDIN=true; SELECTOR_COUNT=$((SELECTOR_COUNT+1));shift ;;
    --regex-from-stdin) REGEX_FROM_STDIN=true; SELECTOR_COUNT=$((SELECTOR_COUNT+1));shift ;;
    --sep) STDIN_SEP="$2"; shift 2 ;;
    --older-than) OLDER_THAN="$2"; SELECTOR_COUNT=$((SELECTOR_COUNT+1));shift 2 ;;
    --younger-than) YOUNGER_THAN="$2"; SELECTOR_COUNT=$((SELECTOR_COUNT+1)); shift 2 ;;
    --time-left) TIME_LEFT="$2"; SELECTOR_COUNT=$((SELECTOR_COUNT+1)); shift 2 ;;
    --latest) LATEST=true; SELECTOR_COUNT=$((SELECTOR_COUNT+1));shift ;;
    --state) SELECTOR_COUNT=$((SELECTOR_COUNT+1)); args::parse_state "$2"; shift 2 ;;
    --partition) PARTITION_FILTER="$2"; SELECTOR_COUNT=$((SELECTOR_COUNT+1)); shift 2 ;;
    --dry-run) DRY=true; shift ;;
    --force) FORCE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    --version) util::version; exit 0 ;;
    --verbose) SSC_LOG_LEVEL=info; shift ;;
    --debug) SSC_LOG_LEVEL=debug; shift ;;
    *) die 2 "Unknown argument: $1 (see --help)";;
  esac
done

if (( SELECTOR_COUNT == 0 )); then
  die 2 "Refusing to operate with no filter selector. Use one of: --this-dir, --dir, --name, --contains, --contains-from-stdin, --latest, --state, --partition, --older-than, --younger-than, --time-left."
fi

if $CONTAINS_FROM_STDIN && $REGEX_FROM_STDIN; then
  die 2 "Cannot combine --contains-from-stdin and --regex-from-stdin in the same call."
fi

# Read patterns from stdin if requested
if $CONTAINS_FROM_STDIN; then
  mapfile -t CONTAINS_JOB_NAMES < <(util::read_patterns_from_stdin "$STDIN_SEP")
  ((${#CONTAINS_JOB_NAMES[@]} > 0)) || die 2 "--contains-from-stdin received no jobnames. Did you pass the correct separator(--sep)?"
fi

if $REGEX_FROM_STDIN; then
  mapfile -t REGEX_PATTERNS < <(util::read_patterns_from_stdin "$STDIN_SEP")
  ((${#REGEX_PATTERNS[@]} > 0)) || die 2 "--regex-from-stdin received no patterns. Did you pass the correct separator(--sep)?"
fi

# Fetch dependency data only when the configured policy can use it. When it is
# enabled, job records and dependencies still come from one scheduler snapshot.
DEPENDENCY_CACHE=""
if $INCLUDE_DEPENDENTS; then
  SQUEUE_SNAPSHOT="$(slurm::squeue_lines_with_dependencies "$STATE_FILTER")"
  SQUEUE_CACHE="$(awk -F'|' 'BEGIN {OFS="|"} NF {print $1,$2,$3,$4,$5,$6,$7,$8,$9}' <<<"$SQUEUE_SNAPSHOT")"
  DEPENDENCY_CACHE="$(awk -F'|' 'NF {print $1 "|" $10}' <<<"$SQUEUE_SNAPSHOT")"
else
  SQUEUE_CACHE="$(slurm::squeue_lines "$STATE_FILTER")"
fi
CANDIDATES="$SQUEUE_CACHE"

if $THIS_DIR || [[ -n "$DIR_FILTER" ]]; then
  dir="${DIR_FILTER:-$PWD}"
  [[ -d "$dir" ]] || die 2 "Directory not found: $dir"
  CANDIDATES="$(printf '%s\n' "$CANDIDATES" | util::apply_dir_filter_with_fallback "$dir")"
  [[ -z "$CANDIDATES" ]] && { echo "No jobs found for this directory: $dir"; exit 0; }
  log_jobs_count "after dir filter" "$CANDIDATES"
fi

# Name filters
if [[ -n "$NAME_EQ" ]]; then
  CANDIDATES="$(printf '%s\n' "$CANDIDATES" | util::filter_candidates_by_field_values 2 "$NAME_EQ")"
  log_jobs_count "after --name '$NAME_EQ'" "$CANDIDATES"
fi

if [[ -n "$NAME_CONTAINS" ]]; then
  CANDIDATES="$(printf '%s\n' "$CANDIDATES" | util::filter_candidates_by_field_contains 2 "$NAME_CONTAINS")"
  log_jobs_count "after --contains '$NAME_CONTAINS'" "$CANDIDATES"
fi

if [[ -n "$NAME_REGEX" ]]; then
  CANDIDATES="$(printf '%s\n' "$CANDIDATES" | util::filter_candidates_by_field_regex 2 "$NAME_REGEX")"
  log_jobs_count "after --regex '$NAME_REGEX'" "$CANDIDATES"
fi

# Multiple contains patterns from stdin
if ((${#CONTAINS_JOB_NAMES[@]} > 0)); then
  CANDIDATES="$(printf '%s\n' "$CANDIDATES" | util::filter_candidates_by_field_contains 2 "${CONTAINS_JOB_NAMES[@]}")"
  log_jobs_count "after --contains-from-stdin" "$CANDIDATES"
fi

# Regex-from-stdin (many patterns, treated as regex alternation)
if ((${#REGEX_PATTERNS[@]} > 0)); then
  CANDIDATES="$(printf '%s\n' "$CANDIDATES" | util::filter_candidates_by_field_regex 2 "${REGEX_PATTERNS[@]}")"
  log_jobs_count "after --regex-from-stdin" "$CANDIDATES"
fi

if [[ -n "$PARTITION_FILTER" ]]; then
  CANDIDATES="$(printf '%s\n' "$CANDIDATES" | util::filter_candidates_by_partition "$PARTITION_FILTER")"
  log_jobs_count "after --partition '$PARTITION_FILTER'" "$CANDIDATES"
fi

# Time filter in pure Bash (no awk math needed)
if [[ -n "$OLDER_THAN" ]]; then
  CANDIDATES="$(printf '%s\n' "$CANDIDATES" | util::filter_candidates_older_than "$OLDER_THAN")"
  log_jobs_count "after --older-than '$OLDER_THAN'" "$CANDIDATES"
fi

if [[ -n "$YOUNGER_THAN" ]]; then
  CANDIDATES="$(printf '%s\n' "$CANDIDATES" | util::filter_candidates_younger_than "$YOUNGER_THAN")"
  log_jobs_count "after --younger-than '$YOUNGER_THAN'" "$CANDIDATES"
fi

if [[ -n "$TIME_LEFT" ]]; then
  CANDIDATES="$(printf '%s\n' "$CANDIDATES" | util::filter_candidates_time_left "$TIME_LEFT")"
  log_jobs_count "after --time-left '$TIME_LEFT'" "$CANDIDATES"
fi

# Latest only
if $LATEST; then
  CANDIDATES="$(util::pick_latest_line <<<"$CANDIDATES")"
  log_jobs_count "after --latest" "$CANDIDATES"
fi

if [[ -n "$REASON_FILTER" ]]; then
  CANDIDATES="$(awk -F'|' -v r="$REASON_FILTER" '$7 ~ r' <<<"$CANDIDATES")"
  log_jobs_count "after reason filter '$REASON_FILTER'" "$CANDIDATES"
fi

# Build one canonical final cancellation list, then derive the visible details
# from that exact list. Nothing is recomputed after confirmation.
FINAL_IDS="$(cut -d'|' -f1 <<<"$CANDIDATES" | sed '/^$/d' | sort -u)"
if [[ -n "$FINAL_IDS" ]] && $INCLUDE_DEPENDENTS; then
  before_count="$(wc -l <<<"$FINAL_IDS" | tr -d ' ')"
  FINAL_IDS="$(slurm::expand_with_dependents "$DEPENDENCY_CACHE" "$FINAL_IDS")"
  after_count="$(wc -l <<<"$FINAL_IDS" | tr -d ' ')"
  if (( after_count > before_count )); then
    echo "Info: included $((after_count - before_count)) dependent job(s) in the cancellation preview." >&2
  fi
fi

# --- Act
if [[ -z "$FINAL_IDS" ]]; then
  log_error "No matching jobs."
  exit 0
fi

mapfile -t FINAL_ID_ARRAY <<<"$FINAL_IDS"
FINAL_CANDIDATES="$(printf '%s\n' "$SQUEUE_CACHE" \
  | util::filter_candidates_by_field_values 1 "${FINAL_ID_ARRAY[@]}")"
FINAL_COUNT="${#FINAL_ID_ARRAY[@]}"

# Bold header (using ANSI codes)
echo -e "\e[1mJobs to cancel\e[0m"

# Pretty table with Reason (field 7)
awk -F'|' '
BEGIN {
  printf("%-12s %-20s %-10s %-25s %-s\n", "JobID", "JobName", "State", "Reason", "WorkDir")
}
{
  printf("%-12s %-20s %-10s %-25s %-s\n", $1, $2, $3, $7, $4)
}' <<<"$FINAL_CANDIDATES"

if $DRY; then
  echo
  echo "Dry-run (no changes):"
  while read -r id; do
    [[ -n "$id" ]] && echo "scancel $id"
  done <<< "$FINAL_IDS"
  exit 0
fi

if $CONFIRM_ENABLED && ! $FORCE; then
  echo
  confirm "Cancel $FINAL_COUNT job(s)?" || { echo "Aborted."; exit 1; }
fi

# Execute
while read -r id; do
  [[ -z "$id" ]] && continue
  scancel "$id" || log_error "Failed to cancel $id"
done <<< "$FINAL_IDS"

log_info "Done."
