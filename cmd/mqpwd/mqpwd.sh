#!/usr/bin/env bash
# mqpwd — list jobs associated with sbatch scripts in a directory
# Usage:
#   mqpwd            # uses $PWD
#   mqpwd /path/to/dir
set -Eeuo pipefail
IFS=$'\n\t'

SSC_HOME="${SSC_HOME:-"$(cd "$(dirname "$0")/../.." && pwd)"}"
source "$SSC_HOME/lib/core.sh"
source "$SSC_HOME/lib/slurm.sh"
# source "$SSC_HOME/lib/colors.sh"; color::setup auto

# Accept 0 or 1 argument (directory)
if [[ $# -gt 1 ]]; then
  echo "mqpwd: at most one PATH argument is allowed" >&2
  exit 2
fi

dir="${1:-$PWD}"
[[ -d "$dir" ]] || die 2 "Directory not found: $dir"

# Get job names from #SBATCH --job-name in top-level *.sh of the directory
mapfile -t names < <(slurm::job_names_from_dir "$dir")
[[ ${#names[@]} -gt 0 ]] || {
  echo "No #SBATCH --job-name found in *.sh under: $dir" >&2
  exit 0
}

# Query squeue for these names (current user)
lines="$(slurm::squeue_by_job_names "$(id -un)" "${names[@]}")"
[[ -z "$lines" ]] && { echo "No matching jobs found in queue."; exit 0; }

# Header with Reason
printf "%-10s %-8s %-35s %-10s %-19s %-20s %s\n" \
  "JOBID" "STATE" "NAME" "ELAPSED" "START_TIME" "REASON" "WORKDIR"

# Rows (notice $7 for Reason)
awk -F'|' '{printf "%-10s %-8s %-35s %-10s %-19s %-20s %s\n", $1,$3,$2,$5,$6,$7,$4}' <<<"$lines"



