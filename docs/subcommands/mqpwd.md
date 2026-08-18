# mqpwd

This command gets the jobs which are related to the current directory which you are in (if no args are passed).
If filters provided, they will be used to sort the jobs from the `squeue`.
## Usage

mqpwd [PATH] [FILTERS]

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
| `--regex PATTERN` | show jobs whose names match the regular expression. | Use `.*` for a wildcard-style match. |

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
| `--latest` | show the latest otherwise matching job, without adding a state filter. | Uses StartTime when every match has one; otherwise uses the highest JobID. |

## Additional

| Flag | Description | Notes |
|------|-------------|-------|
| `-h`, `--help` | Show all flags on the terminal. | — |
| `--version` | Shows the version of smartslurmcommands. | - |
| `--verbose` | Prints the information of at what step the code is and how many jobs did it find for the filter you passed. | - |
| `--debug` | Prints the information of at what step the code and outputs the command. | - |

`PATH` is retained as a positional shorthand for `--dir PATH`.
