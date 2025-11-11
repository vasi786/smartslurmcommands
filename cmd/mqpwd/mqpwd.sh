#!/usr/bin/env bash
# mqpwd — list jobs associated with sbatch scripts in a directory
# Usage:
#   mqpwd            # uses $PWD
#   mqpwd /path/to/dir
set -Eeuo pipefail
IFS=$'\n\t'

# shellcheck source=lib/core.sh
# shellcheck source=lib/cfg.sh
# shellcheck source=lib/util.sh
# shellcheck source=lib/slurm.sh
# shellcheck source=lib/ui.sh


SSC_HOME="${SSC_HOME:-"$(cd "$(dirname "$0")/../.." && pwd)"}"
source "$SSC_HOME/lib/core.sh"
source "$SSC_HOME/lib/slurm.sh"
source "$SSC_HOME/lib/util.sh"
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


# Get matching JobIDs for these names
ids="$(slurm::job_ids_by_job_names "$(current_user)" "${names[@]}")"
[[ -z "$ids" ]] && { echo "No matching jobs found in queue."; exit 0; }

# Build a comma-separated list for -j
csv_ids="$(paste -sd, <<<"$ids")"
squeue --me -j "$csv_ids" -o "%.10i %.10P  %35j %.8u %.2t  %.10M [%.10L] %.5m %.5C - %5D %R"

# Header with Reason
# printf "%-10s %-8s %-35s %-10s %-19s %-20s %s\n" \
#   "JOBID" "STATE" "NAME" "ELAPSED" "START_TIME" "REASON"
#
# # Rows (notice $7 for Reason)
# awk -F'|' '{printf "%-10s %-8s %-35s %-10s %-19s %-20s %s\n", $1,$3,$2,$5,$6,$7,$4}' <<<"$lines"



