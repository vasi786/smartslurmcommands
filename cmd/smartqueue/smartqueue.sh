#!/usr/bin/env bash
# smartqueue - smarter wrapper around scancel focused on dir/name workflows.
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

usage() {
  cat <<'EOF'
  Usage: smartqueue [FILTERS]

  Filters (combine as needed):
    --this-dir                   Show jobs whose WorkDir == $PWD or fallback to the job_name found in the CWD.
    --dir PATH                   Show jobs whose WorkDir == PATH or fallback to the job_name found in the PATH.
    --name NAME                  Show jobs with exact job name match.
    --contains SUBSTR            Show jobs with job name contains substring.
    --contains-from-stdin        With this option, smartqueue accept's substring from stdin (ex: somecommand |smartqueue --contains-from-stdin).
    --regex PATTERN              Show jobs with job names which matches the provided regex pattern.
    --regex-from-stdin           With this option, smartqueue accept's regex patterns from stdin (ex: somecommand |smartqueue --regex-from-stdin).
    --older-than DUR             Show jobs that have elapsed time > DUR (e.g., 10m, 2h).
    --state STATE                Show jobs in this Slurm state (e.g., RUNNING, PENDING, DEPENDENCY) - non-case-sensitive. Dependency is the only excpetion which is treated as state.
    --partition NAME[,NAME...]   Show jobs in these Slurm partitions.
    --latest                     Show latest job (by StartTime or JobID).

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
STATE_FILTER=""
PARTITION_FILTER=""
# currently reason filter is only used when --state dependency is supplied
REASON_FILTER=""
LATEST=false
CONTAINS_FROM_STDIN=false
REGEX_FROM_STDIN=false
STDIN_SEP=$'\n'   # default = newline
declare -a CONTAINS_JOB_NAMES=() # will be used for contains-from-stdin, for taking the multiple inputs from the stdin and treats as part or whole job names
declare -a REGEX_PATTERNS=() # will be used for regex-from-stdin, for taking the multiple inputs from the stdin and treats as part or whole job names
SSC_LOG_LEVEL="${SSC_LOG_LEVEL:-none}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --this-dir) THIS_DIR=true; shift ;;
    --dir) DIR_FILTER="$2"; shift 2 ;;
    --name) NAME_EQ="$2"; shift 2 ;;
    --contains) NAME_CONTAINS="$2"; shift 2 ;;
    --regex) NAME_REGEX="$2"; shift 2 ;;
    --contains-from-stdin) CONTAINS_FROM_STDIN=true; shift ;;
    --regex-from-stdin) REGEX_FROM_STDIN=true; shift ;;
    --sep) STDIN_SEP="$2"; shift 2 ;;
    --older-than) OLDER_THAN="$2"; shift 2 ;;
    --latest) LATEST=true; STATE_FILTER="RUNNING"; shift ;;
    --state)  args::parse_state "$2"; shift 2 ;;
    --partition) PARTITION_FILTER="$2";  shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --version) util::version; exit 0 ;;
    --verbose) SSC_LOG_LEVEL=info; shift ;;
    --debug) SSC_LOG_LEVEL=debug; shift ;;
    *) die 2 "Unknown argument: $1 (see --help)";;
  esac
done

# Read patterns from stdin if requested
if $CONTAINS_FROM_STDIN; then
  mapfile -t CONTAINS_JOB_NAMES < <(util::read_patterns_from_stdin "$STDIN_SEP")
  ((${#CONTAINS_JOB_NAMES[@]} > 0)) || die 2 "--contains-from-stdin received no jobnames. Did you pass the correct separator(--sep)?"
fi

if $REGEX_FROM_STDIN; then
  mapfile -t REGEX_PATTERNS < <(util::read_patterns_from_stdin "$STDIN_SEP")
  ((${#REGEX_PATTERNS[@]} > 0)) || die 2 "--regex-from-stdin received no patterns. Did you pass the correct separator(--sep)?"
fi

# Return lines: JobID|JobName|State|WorkDir|Elapsed|StartTime|Reason|Partition for a user (default: current)
SQUEUE_CACHE="$(slurm::squeue_lines "$STATE_FILTER")"
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

if [[ -n "$OLDER_THAN" ]]; then
  filtered=""
  while IFS='|' read -r jid jname state wdir elapsed start; do
    [[ -z "$jid" ]] && continue
    if util::older_than "$elapsed" "$OLDER_THAN"; then
      filtered+="$jid|$jname|$state|$wdir|$elapsed|$start"$'\n'
    fi
  done <<< "$CANDIDATES"
  CANDIDATES="$filtered"
  log_jobs_count "after --older-than '$OLDER_THAN'" "$CANDIDATES"
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

ids="$(
 printf '%s\n' "$CANDIDATES" \
 | awk -F'|' 'NF && $1 ~ /^[0-9]+$/ { print $1 }' \
 | sort -u
)"

if [[ -z "$ids" ]]; then
 echo "No valid job IDs to query." >&2
 exit 0
fi

csv_ids="$(printf '%s\n' "$ids" | paste -sd, -)"
# Same columns as your alias:
#   %.10i %.10P  %35j %.8u %.2t  %.10M [%.10L] %.5m %.5C - %5D %R
require_cmd squeue
squeue --me -j "$csv_ids" -o '%.10i %.10P  %35j %.8u %.2t  %.10M [%.10L] %.5m %.5C - %5D %R'
