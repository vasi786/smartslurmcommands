#!/usr/bin/env bash
# mqpwd — list jobs associated with sbatch scripts OR working directory
# Usage:
#   mqpwd            # uses $PWD
#   mqpwd /path/to/dir
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

  mqpwd PATH
      Same as above but using PATH instead of $PWD.

Behavior:
  • If the directory contains *.sh scripts with "#SBATCH --job-name", those
    job names are extracted and used to filter squeue output.

  • If no job-name lines are found, mqpwd falls back to matching jobs whose
    WorkDir exactly matches the directory.

Output:
  Matches are printed using your mq-style squeue formatting.

Examples:
  mqpwd
  mqpwd ~/projects/my_sim
  mqpwd /scratch/work/pex13/simR2

Notes:
  This command NEVER cancels any job — it is read-only and safe.

EOF
}

# Accept 0 or 1 argument (directory), or --help
if [[ $# -gt 1 ]]; then
  echo "mqpwd: at most one PATH argument is allowed" >&2
  exit 2
fi

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

dir="${1:-$PWD}"
[[ -d "$dir" ]] || die 2 "Directory not found: $dir"

# Resolve absolute, physical path (keeps tests & matching consistent)
if command -v realpath >/dev/null 2>&1; then
  absdir="$(realpath "$dir")"
else
  absdir="$(cd "$dir" && pwd -P)"
fi

# Build a cache of this user’s jobs in our pipe format:
# %i|%j|%T|%Z|%M|%S|%R|%P  → id|name|state|workdir|elapsed|start|reason|partition
SQUEUE_CACHE="$(slurm::squeue_lines)"   # make sure this outputs the 8 fields above

# Filter by names from *.sh in dir OR by WorkDir==absdir (union, dedup)
filtered="$(printf '%s\n' "$SQUEUE_CACHE" | util::apply_dir_filter_with_fallback "$absdir")"

if [[ -z "$filtered" ]]; then
  echo "No jobs found related to: $absdir"
  exit 0
fi

# Extract job IDs and print like your `mq` alias
csv_ids="$(cut -d'|' -f1 <<<"$filtered" | sed '/^$/d' | paste -sd, -)"
if [[ -z "$csv_ids" ]]; then
  echo "No job IDs found after filtering for: $absdir"
  exit 0
fi

# Same columns as your alias:
#   %.10i %.10P  %35j %.8u %.2t  %.10M [%.10L] %.5m %.5C - %5D %R
require_cmd squeue
squeue --me -j "$csv_ids" -o "%.10i %.10P  %35j %.8u %.2t  %.10M [%.10L] %.5m %.5C - %5D %R"

