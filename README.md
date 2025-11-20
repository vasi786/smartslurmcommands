<!-- # smartslurmcommands (ssc) -->
![image](images/github_banner.png)

smartslurmcommands (SSC) is a slurm command wrapper that provides enhanced slurm utilities with advanced filtering for job discovery and their cancellation (if needed).

## Table of Contents

- [Installation](#installation)
- [Featured Flags](#featured-flags)
- [smartqueue](#smartqueue)
- [smartcancel](#smartcancel)
- [mqpwd](#mqpwd)
- [motivation](#motivation)
- [License](./LICENSE)

---
## Installation

Run this one-liner to install the latest release:

```bash
curl -sL https://raw.githubusercontent.com/vasi786/smartslurmcommands/main/install_latest.sh | bash
```

## Featured Flags

Combine the flags as needed)

| Flag | Description |
|------|-------------|
| `--this-dir` | Fetch jobs related to the current working directory. |
| `--dir PATH` | Fetch jobs related to the provided `PATH`. |
| `--latest` | Fetch the latest job in the `squeue`. |
| `--older-than DUR` | Fetch jobs with elapsed time greater than `DUR` (e.g., `10m`, `2h`). |
| `--contains SUBSTR` | Fetch job names containing the specified substring of a jobname. |
| `--regex PATTERN` | Show jobs with job names which matches the provided regex pattern. |
| <code>somecommand &#124; smartcancel --contains-from-stdin</code> | Fetch job names containing substrings (of a jobname) passed through STDIN. |
| <code>somecommand &#124; smartcancel --regex-from-stdin</code> | Fetch job names matching regex patterns passed through STDIN. |
| `--dry-run` | In case of `smartcancel`, this flag will show the jobs that will be cancelled. |


## [smartqueue](./docs/subcommands/smartqueue.md)
  smartqueue is a smarter squeue wrapper that helps you inspect slurm jobs using intuitive, workflow-oriented filters.
  It can match jobs by directory, job-name, substring, regex, stdin patterns, or pick only the latest matching job.
  The above featured flags are just a subset of features.
  For full view of feature, see [here](./docs/subcommands/smartqueue.md)

 Why stop just viewing the jobs, Do you want to cancel the ones you have viewed? (see below).

## [smartcancel](./docs/subcommands/smartcancel.md)
  This is the command I wanted during my PhD (see Motivation).
  The biggest use case for me was to detect the jobs which are associated with the current working directory (I am in) and use that to fetch the jobs and cancel them.

  Detailed explanation of all the available flags can be found here: [smartcancel](./docs/subcommands/smartcancel.md).
  If you prefer directly looking at the examples: [smartcancel-examples](./docs/subcommands/smartcancel_examples.md).

  ### Examples
  - If my queue is as below:
    ```
    [user@int4 20_pq_charmmR1_bigger_box_20nm_with_Lysines]$ mq
        JOBID  PARTITION  NAME                                    USER ST        TIME [ TIME_LEFT] MIN_M  CPUS - NODES NODELIST(REASON)
     15858563      genoa  20_pq_with_Lys_AR1                    user PD        0:00 [5-00:00:00]  100G   384 - 2     (Dependency)
     15858314      genoa  20_pq_with_Lys_CR1                    user PD        0:00 [5-00:00:00]  100G   384 - 2     (Dependency)
     15819623      genoa  pex13_nterminal_10copies              user  R    23:38:52 [4-00:21:08]  100G   960 - 5     tcn[1086-1089,1101]
     15858313      genoa  20_pq_with_Lys_CR1                    user  R  3-05:33:30 [1-18:26:30]  100G   384 - 2     tcn[549,594]
     15858562      genoa  20_pq_with_Lys_AR1                    user  R  3-04:47:42 [1-19:12:18]  100G   384 - 2     tcn[743-744]
     15819552      genoa  Q44_c2_3_restart1                     user  R    23:39:53 [4-00:20:07]  100G   384 - 2     tcn[1099-1100]
     15819484      genoa  Q44_c2_2_restart1                     user  R    23:44:27 [4-00:15:33]  100G   384 - 2     tcn[558,1179]
     15819331      genoa  Q44_c2_1_restart1                     user  R    23:48:30 [4-00:11:30]  100G   384 - 2     tcn[1024-1025]
    ```

  - To find the job related to the current working directory and cancel it.
    <details>
    <summary>Example output of <code>smartcancel --this-dir</code></summary>

    ```bash
    [user@int4 20_pq_charmmR1_bigger_box_20nm_with_Lysines]$ smartcancel --this-dir --dry-run
    Jobs to cancel
    JobID        JobName              State      Reason                    WorkDir
    15858314     20_pq_with_Lys_CR1   PENDING    (Dependency)              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_charmmR1_bigger_box_20nm_with_Lysines
    15858313     20_pq_with_Lys_CR1   RUNNING    tcn[549,594]              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_charmmR1_bigger_box_20nm_with_Lysines

    Dry-run (no changes):
    scancel 15858313
    scancel 15858314
    ```
    </details>

  - To find the job related to a different directory and cancel it.
    <details>
    <summary>Example output of <code>smartcancel --dir PATH</code></summary>

    ```bash
    [user@int4 20_pq_charmmR1_bigger_box_20nm_with_Lysines]$ smartcancel --dir ../20_pq_amberR1_bigger_box_20nm_with_Lysines/ --dry-run
    Jobs to cancel
    JobID        JobName              State      Reason                    WorkDir
    15858563     20_pq_with_Lys_AR1   PENDING    (Dependency)              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_amberR1_bigger_box_20nm_with_Lysines
    15858562     20_pq_with_Lys_AR1   RUNNING    tcn[743-744]              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_amberR1_bigger_box_20nm_with_Lysines

    Dry-run (no changes):
    scancel 15858562
    scancel 15858563
    ```
    </details>

  - To find the latest job in the squeue and cancel it.
    <details>
    <summary>Example output of <code>smartcancel --latest</code></summary>

    ```bash
    [user@int4 20_pq_charmmR1_bigger_box_20nm_with_Lysines]$ smartcancel --latest --dry-run
    Jobs to cancel
    JobID        JobName              State      Reason                    WorkDir
    15819623     pex13_nterminal_10copies RUNNING    tcn[1086-1089,1101]       /gpfs/work3/0/ugc20675/Vasista/postdoc/peroxisomes/Nterminal/10molecules/R1

    Dry-run (no changes):
    scancel 15819623
    ```
    </details>

## [mqpwd](./docs/subcommands/mqpwd.md)
mqpwd &rarr; mq-squeue-pwd: This command gets the jobs which are related to the current directory which you are in (if no args are passed).
Same filters which are passed to `smartcancel|smartqueue` can be passed to `mqpwd` to sort the jobs from the queue.
List of all the implemented filters are detailed [here](./docs/subcommands/mqpwd.md).
<details>
<summary>Example output of <code>mqpwd</code></summary>

```bash
[user@int4 20_pq_charmmR1_bigger_box_20nm_with_Lysines]$ mqpwd
    JOBID  PARTITION  NAME                                    USER ST        TIME [ TIME_LEFT] MIN_M  CPUS - NODES NODELIST(REASON)
 15858314      genoa  20_pq_with_Lys_CR1                    user PD        0:00 [5-00:00:00]  100G   384 - 2     (Dependency)
 15858313      genoa  20_pq_with_Lys_CR1                    user  R  3-05:08:38 [1-18:51:22]  100G   384 - 2     tcn[549,594]

[user@int4 20_pq_charmmR1_bigger_box_20nm_with_Lysines]$ mqpwd ../20_pq_amberR1_bigger_box_20nm_with_Lysines/
    JOBID  PARTITION  NAME                                    USER ST        TIME [ TIME_LEFT] MIN_M  CPUS - NODES NODELIST(REASON)
 15858563      genoa  20_pq_with_Lys_AR1                    user PD        0:00 [5-00:00:00]  100G   384 - 2     (Dependency)
 15858562      genoa  20_pq_with_Lys_AR1                    user  R  3-04:23:14 [1-19:36:46]  100G   384 - 2     tcn[743-744]
```
</details>

## Motivation
After four and half years of PhD in computational biophysics (currently a postdoc), with a lot of usage of HPC, the biggest issue I faced is the effort it takes to cancel jobs.
For example, I submitted a simulation, and realized that I have missed a parameter and want to cancel that
job among hundreds of jobs I am running at the same time. Finding this job ID is a challenge, and I always thought of adding my own alias which does this for me smartly.
You could ask, why not use the job name. In my case the job name is a 32 character random string sometimes, and I would like to minimize the operations to cancel the latest job which I submitted an hour ago.
I was surprised that this functionality doesn't exist natively or someone didn't develop a tool for these use cases.
Thus, I took myself the challenge (fed it to GPT mostly) and wrote this wrapper commands on top of native slurm commands which are used by daily user to make things smarter and efficient in the world of a HPC user.
