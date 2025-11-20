# smartqueue
This command is similar to squeue, but with additional arguments to better filter jobs you want to see.

## Usage

smartqueue [FILTERS]

## Filters

### Directory-based Filters

| Flag | Description | Notes |
|------|-------------|-------|
| `--this-dir` | Show jobs whose `WorkDir == $PWD`. Also scans `.sh` files in the directory for `--job-name` flags and uses those job names as filters. | Final match set is the **union** of both criteria (duplicates removed). |
| `--dir PATH` | Show jobs whose `WorkDir == PATH`. Also scans `.sh` files in the directory for `--job-name` flags and uses those job names as filters. | Final match set is the **union** of both criteria (duplicates removed). |

### Name-based Filters

| Flag | Description | Notes |
|------|-------------|-------|
| `--name NAME` | Exact job name match. | — |
| `--contains SUBSTR` | Match jobs whose name contains `SUBSTR`. | No wildcards allowed. |
| `--regex PATTERN` | Show jobs with job names which matches the provided regex pattern. | specific for regular expressions. For wildcard, use `.*` |
| `--contains-from-stdin` | Accept name patterns from STDIN. | Just provide list of substrings seperated by a separator supplied by `--sep` flag. See examples section. ([Examples](smartcancel_examples.md)) |
| `--regex-from-stdin` | With this option, smartqueue accept's regex patterns from stdin (ex: somecommand \|smartqueue --regex-from-stdin).  | Just provide list of regular expressions with seperators specified by `--sep` flag|
| `--sep SEP` | provide a separator to tell the wrapper how to break your stdin input provided with `--contains-from-stdin` and `--regex-from-stdin` flags | almost all kinds of seperators will work (Hopefully!) |

### Duration & State Filters

| Flag | Description | Notes |
|------|-------------|-------|
| `--older-than DUR` | Only jobs with elapsed time > `DUR` (e.g. `10m`, `2h`). | — |
| `--state STATE` | Only jobs in this Slurm state (case-insensitive). Dependency "reason" from `squeue` is treated as a state. | Examples: `RUNNING`, `PENDING`, `DEPENDENCY`. |

### Partition Filter

| Flag | Description | Notes |
|------|-------------|-------|
| `--partition NAME[,NAME...]` | Match only jobs running on the given node partitions. | — |

### Latest-job Filter

| Flag | Description | Notes |
|------|-------------|-------|
| `--latest` | Select only the latest matching job (by StartTime or JobID). | — |

## Additional

| Flag | Description | Notes |
|------|-------------|-------|
| `-h`, `--help` | Show all flags on the terminal. | — |
| `--version` | Shows the version of smartslurmcommands. | - |
| `--verbose` | Prints the information of at what step the code is and how many jobs did it find for the filter you passed. | - |
| `--debug` | Prints the information of at what step the code and outputs the command. | - |


See the detailed command examples here: [Examples](smartcancel_examples.md).
