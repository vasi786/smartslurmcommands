# smartcancel

## Usage

Usage: smartcancel [FILTERS] [BEHAVIOR]

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
Only jobs in this Slurm state (case-insensitive).
Examples: `RUNNING`, `PENDING`, `DEPENDENCY`.

### Partition filter

- `--partition NAME[,NAME...]`
Only jobs in these Slurm partitions.

### Latest-job filter

- `--latest`
Pick only the latest matching job (by StartTime or JobID).

## Behavior

- `--dry-run`
Show what would be cancelled.

- `--force`
Do not prompt.

- `-h`, `--help`
Show this help.
