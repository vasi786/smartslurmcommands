# Prepend tests/helpers/slurm_mocks to PATH for fake slurm binaries
export PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/slurm_mocks:$PATH"
