# smartcancel
This command with a filters (see below) will cancel a job. Before cancelling a final confirm question with (yes/no) will be asked to confirm the cancellation of the job.
If no filters are passed, the command will exit with a warning.

## Usage

Usage: smartcancel [FILTERS] [BEHAVIOR (optional)]

## Filters

You may combine multiple filters.

### Directory-based filters

- `--this-dir`
  Cancel jobs whose `WorkDir == $PWD`.
  Additionally, if any `.sh` file in the directory was found with a `--job-name` flag, that job name is also used as a filter.
  The final match set is the **union** of both criteria (with duplicates removed).

- `--dir PATH`
  Cancel jobs whose `WorkDir == PATH`
  Additionally, if any `.sh` file in the directory was found with a `--job-name` flag, that job name is also used as a filter.
  The final match set is the **union** of both criteria (with duplicates removed).

### Name-based filters

- `--name NAME`
  Exact job name match.

- `--contains SUBSTR`
  Job name contains substring (no wildcards allowed).

- `--contains-from-stdin`
  Accept patterns from stdin


### Duration & state filters

- `--older-than DUR`
Only jobs with elapsed time > `DUR` (e.g. `10m`, `2h`).

- `--state STATE`
Only jobs in this Slurm state (case-insensitive) will be filtered.
Dependency which is a `reason` in the `squeue` output is also considered as a state.
Examples: `RUNNING`, `PENDING`, `DEPENDENCY`.

### Partition filter

- `--partition NAME[,NAME...]`
Only jobs which on these node partitions will be filtered.

### Latest-job filter

- `--latest`
Pick only the latest matching job (by StartTime or JobID).

## Behavior (optional)

- `--dry-run`
Show what would be cancelled.

- `--force`
Do not prompt the `confirm (yes/no)` statement before cancelling the job.

### Additional

- `-h`, `--help`
Show all these flags on the terminal.

See the detailed command examples here: [Examples](smartcancel_examples.md).
