#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# --- Libs (keep order: core -> cfg -> log -> io/util -> slurm)
SSC_HOME="${SSC_HOME:-"$(cd "$(dirname "$0")/../.." && pwd)"}"
source "$SSC_HOME/lib/core.sh"
source "$SSC_HOME/lib/cfg.sh";      cfg::load
source "$SSC_HOME/lib/log.sh"
source "$SSC_HOME/lib/util.sh"
source "$SSC_HOME/lib/args.sh"
source "$SSC_HOME/lib/slurm.sh"
source "$SSC_HOME/lib/io.sh"
source "$SSC_HOME/lib/selfupdate.sh"

usage() {
  cat <<'EOF'
Usage: ssc [OPTIONS]

Options:
  --update [--tag TAG]         Update smartslurmcommands.
                               Without --tag, fetches and installs the latest
                               GitHub release. With --tag, installs that
                               specific version (e.g. v0.2.1).

  --version                    Show the installed smartslurmcommands version.
  -h, --help                   Show this help.
EOF
}

MODE=""
UPDATE_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --update)
      MODE="update"
      shift
      # Everything after --update belongs to the self-update logic
      UPDATE_ARGS=("$@")
      break
      ;;
    --version)
      util::version
      exit 0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die 2 "Unknown argument: $1 (see --help)"
      ;;
  esac
done

case "$MODE" in
  update)
    ssc::self_update "${UPDATE_ARGS[@]}"
    exit $?
    ;;
  "")
    # No mode chosen, just show help and exit with error
    usage
    exit 2
    ;;
esac
