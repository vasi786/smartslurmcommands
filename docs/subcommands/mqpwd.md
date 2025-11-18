
## Usage

mqpwd [FILTERS]

## Filters

### Directory-based Filters

| Flag | Description | Notes |
|------|-------------|-------|
| `--this-dir` | (**default filter**) shows jobs whose `WorkDir == $PWD`. Also scans `.sh` files in the directory for `--job-name` flags and uses those job names as filters. | Final match set is the **union** of both criteria (duplicates removed). |
| `--dir PATH` | show jobs whose `WorkDir == PATH`. Also scans `.sh` files in the directory for `--job-name` flags and uses those job names as filters. | Final match set is the **union** of both criteria (duplicates removed). |

### Name-based Filters

| Flag | Description | Notes |
|------|-------------|-------|
| `--name NAME` | shows jobs with exact job name match. | — |
| `--contains SUBSTR` | show only the ones which match jobs whose name contains `SUBSTR`. | No wildcards allowed. |

### Duration & State Filters

| Flag | Description | Notes |
|------|-------------|-------|
| `--older-than DUR` | show only jobs with elapsed time > `DUR` (e.g. `10m`, `2h`). | — |
| `--state STATE` | show only jobs in this Slurm state (case-insensitive). Dependency "reason" from `squeue` is also treated as a state. | Examples: `RUNNING`, `PENDING`, `DEPENDENCY`.<br>Job reasons: see Slurm docs. |

### Partition Filter

| Flag | Description | Notes |
|------|-------------|-------|
| `--partition NAME[,NAME...]` | show only the ones which match jobs running on the given node partitions. | — |

### Latest-job Filter

| Flag | Description | Notes |
|------|-------------|-------|
| `--latest` | show only the latest matching job (by StartTime or JobID). | — |


## Additional

| Flag | Description | Notes |
|------|-------------|-------|
| `-h`, `--help` | Show all flags on the terminal. | — |
