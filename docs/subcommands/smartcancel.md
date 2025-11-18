# smartcancel
This command with a filters (see below) will cancel a job. Before cancelling a final confirm question with (yes/no) will be asked to confirm the cancellation of the job.
If no filters are passed, the command will exit with a warning.

## Usage

smartcancel [FILTERS] [BEHAVIOR (optional)]

## Filters

### Directory-based Filters

| Flag | Description | Notes |
|------|-------------|-------|
| `--this-dir` | Cancel jobs whose `WorkDir == $PWD`. Also scans `.sh` files in the directory for `--job-name` flags and uses those job names as filters. | Final match set is the **union** of both criteria (duplicates removed). |
| `--dir PATH` | Cancel jobs whose `WorkDir == PATH`. Also scans `.sh` files in the directory for `--job-name` flags and uses those job names as filters. | Final match set is the **union** of both criteria (duplicates removed). |

### Name-based Filters

| Flag | Description | Notes |
|------|-------------|-------|
| `--name NAME` | Exact job name match. | — |
| `--contains SUBSTR` | Match jobs whose name contains `SUBSTR`. | No wildcards allowed. |
| `--contains-from-stdin` | Accept name patterns from STDIN. | See examples section. ([Examples](smartcancel_examples.md)) |

### Duration & State Filters

| Flag | Description | Notes |
|------|-------------|-------|
| `--older-than DUR` | Only jobs with elapsed time > `DUR` (e.g. `10m`, `2h`). | — |
| `--state STATE` | Only jobs in this Slurm state (case-insensitive). Dependency "reason" from `squeue` is also treated as a state. | Examples: `RUNNING`, `PENDING`, `DEPENDENCY`.<br>Job reasons: see Slurm docs. |

### Partition Filter

| Flag | Description | Notes |
|------|-------------|-------|
| `--partition NAME[,NAME...]` | Match only jobs running on the given node partitions. | — |

### Latest-job Filter

| Flag | Description | Notes |
|------|-------------|-------|
| `--latest` | Select only the latest matching job (by StartTime or JobID). | — |

## Behavior (optional)

| Flag | Description | Notes |
|------|-------------|-------|
| `--dry-run` | Show which jobs *would* be cancelled. | No actual cancellation performed. |
| `--force` | Skip confirmation prompt (`confirm (yes/no)`). | — |

## Additional

| Flag | Description | Notes |
|------|-------------|-------|
| `-h`, `--help` | Show all flags on the terminal. | — |


See the detailed command examples here: [Examples](smartcancel_examples.md).
