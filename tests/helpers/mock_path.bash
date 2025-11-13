# Prepend our slurm_mocks dir to PATH for this test file
mock_slurm_path() {
  local here="${BATS_TEST_DIRNAME:-$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd -P)}"
  export PATH="$here/../helpers/slurm_mocks:$PATH"
}
