#!/usr/bin/env bash
# smartqueue - implementation
set -Eeuo pipefail
IFS=$'\n\t'
# shellcheck source=lib/core.sh
source "${SSC_HOME:-$(cd "$(dirname "$0")/../.." && pwd)}/lib/core.sh"
# shellcheck source=lib/cfg.sh
source "${SSC_HOME:-$(cd "$(dirname "$0")/../.." && pwd)}/lib/cfg.sh"
# shellcheck source=lib/slurm.sh
source "${SSC_HOME:-$(cd "$(dirname "$0")/../.." && pwd)}/lib/slurm.sh"

if [[ "${1:-}" =~ ^(--help|-h)$ ]]; then
  cat <<'USAGE'
Usage: smartqueue [options]
Description: smartqueue - smart wrapper for its corresponding Slurm command.
USAGE
  exit 0
fi

echo "smartqueue stub: implement me"
