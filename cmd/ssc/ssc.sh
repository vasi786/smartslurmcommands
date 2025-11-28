#!/usr/bin/env bash
# smartqueue - smarter wrapper around scancel focused on dir/name workflows.
set -Eeuo pipefail
IFS=$'\n\t'

# --- Libs (keep order: core -> cfg -> colors/log -> io/util -> slurm)
SSC_HOME="${SSC_HOME:-"$(cd "$(dirname "$0")/../.." && pwd)"}"
source "$SSC_HOME/lib/selfupdate.sh"

if [[ $# -eq 0 ]]; then
    echo "At least one argument is required. For help, pass --help."
    exit 1
fi

if [[ "$1" == "--update" ]]; then
    shift
    ssc::self_update "$@"
    exit $?
fi
