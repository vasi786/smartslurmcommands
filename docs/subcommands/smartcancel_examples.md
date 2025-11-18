# smartcancel – example commands and outputs

Below are example commands for `smartcancel`, each with a short description and a collapsible section containing the full example output.

---

- `mq` (currently not implemented in the current version, but shouldn't affect the `smartcancel` commands) - To list all your current Slurm jobs, execute:
  ```
    [user@int4 20_pq_amberR1_bigger_box_20nm_with_Lysines]$ mq
    JOBID  PARTITION  NAME                                    USER ST        TIME [ TIME_LEFT] MIN_M  CPUS - NODES NODELIST(REASON)
    15858563      genoa  20_pq_with_Lys_AR1                    user PD        0:00 [5-00:00:00]  100G   384 - 2     (Dependency)
    15858314      genoa  20_pq_with_Lys_CR1                    user PD        0:00 [5-00:00:00]  100G   384 - 2     (Dependency)
    15819623      genoa  pex13_nterminal_10copies              user  R  2-02:48:28 [2-21:11:32]  100G   960 - 5     tcn[1086-1089,1101]
    15858313      genoa  20_pq_with_Lys_CR1                    user  R  4-08:43:06 [  15:16:54]  100G   384 - 2     tcn[549,594]
    15858562      genoa  20_pq_with_Lys_AR1                    user  R  4-07:57:18 [  16:02:42]  100G   384 - 2     tcn[743-744]
    15819552      genoa  Q44_c2_3_restart1                     user  R  2-02:49:29 [2-21:10:31]  100G   384 - 2     tcn[1099-1100]
    15819484      genoa  Q44_c2_2_restart1                     user  R  2-02:54:03 [2-21:05:57]  100G   384 - 2     tcn[558,1179]
    15819331      genoa  Q44_c2_1_restart1                     user  R  2-02:58:06 [2-21:01:54]  100G   384 - 2     tcn[1024-1025]
    ```
- `smartcancel --latest` - if you want to cancel the latest job on the `squeue`:
  <details>
  <summary>example</summary>

  ```bash
  [ponck1@int4 20_pq_amberR1_bigger_box_20nm_with_Lysines]$ smartcancel --latest --dry-run
  Jobs to cancel
  JobID        JobName              State      Reason                    WorkDir
  15819623     pex13_nterminal_10copies RUNNING    tcn[1086-1089,1101]       /gpfs/work3/0/ugc20675/Vasista/postdoc/peroxisomes/Nterminal/10molecules/R1

  Dry-run (no changes):
  scancel  15819623
  ```
  </details>
- `smartcancel --this-dir` - to cancel all the jobs related to the current working directory (CWD) from which you are running this command.

  <details>
  <summary>example</summary>

  ```bash
  [ponck1@int4 20_pq_amberR1_bigger_box_20nm_with_Lysines]$ smartcancel --this-dir --dry-run
  Jobs to cancel
  JobID        JobName              State      Reason                    WorkDir
  15858563     20_pq_with_Lys_AR1   PENDING    (Dependency)              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_amberR1_bigger_box_20nm_with_Lysines
  15858562     20_pq_with_Lys_AR1   RUNNING    tcn[743-744]              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_amberR1_bigger_box_20nm_with_Lysines

  Dry-run (no changes):
  scancel  15858562
  scancel  15858563
  ```
  </details>

- `smartcancel --this-dir --latest` - if you have multiple jobs running in the CWD, and if you want to cancel the latest one:
  <details>
  <summary>example</summary>

  ```bash
  [ponck1@int4 20_pq_amberR1_bigger_box_20nm_with_Lysines]$ smartcancel --this-dir --latest --dry-run
  Jobs to cancel
  JobID        JobName              State      Reason                    WorkDir
  15858562     20_pq_with_Lys_AR1   RUNNING    tcn[743-744]              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_amberR1_bigger_box_20nm_with_Lysines

  Dry-run (no changes):
  scancel  15858562
  ```
  </details>

- `smartcancel --this-dir --older-than 240h` - if you have multiple jobs running in the CWD, and if you want to cancel all the jobs which are older than 10 days:
  <details>
  <summary>example</summary>

  ```bash
  [ponck1@int4 20_pq_amberR1_bigger_box_20nm_with_Lysines]$ smartcancel --this-dir --older-than 240h --dry-run
  info: No matching jobs.
  ```
  </details>

- `smartcancel --this-dir --older-than 40h` - if you have multiple jobs running in the CWD, and if you want to cancel all the jobs which are older than 40 hours:
  <details>
  <summary>example</summary>

  ```bash
  [ponck1@int4 20_pq_amberR1_bigger_box_20nm_with_Lysines]$ smartcancel --this-dir --older-than 40h --dry-run
  Jobs to cancel
  JobID        JobName              State      Reason                    WorkDir
  15858562     20_pq_with_Lys_AR1   RUNNING    tcn[743-744]              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_amberR1_bigger_box_20nm_with_Lysines

  Dry-run (no changes):
  scancel  15858562
  ```
  </details>

- `smartcancel --dir PATH --older-than 40h` - if you want to cancel the jobs from a different directory older than 40 hours:
  <details>
  <summary>example</summary>

  ```bash
  [ponck1@int4 20_pq_amberR1_bigger_box_20nm_with_Lysines]$ smartcancel --dir ../20_pq_charmmR1_bigger_box_20nm_with_Lysines/ --older-than 40h --dry-run
  Jobs to cancel
  JobID        JobName              State      Reason                    WorkDir
  15858313     20_pq_with_Lys_CR1   RUNNING    tcn[549,594]              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_charmmR1_bigger_box_20nm_with_Lysines

  Dry-run (no changes):
  scancel  15858313
  ```
  </details>

- `smartcancel --name NAME` - if you want to cancel a job with a exact match of the name you provide to the command:
  <details>
  <summary>example</summary>

  ```bash
  [ponck1@int4 20_pq_amberR1_bigger_box_20nm_with_Lysines]$ smartcancel --name 20_pq_with_Lys_CR1 --dry-run
  Jobs to cancel
  JobID        JobName              State      Reason                    WorkDir
  15858314     20_pq_with_Lys_CR1   PENDING    (Dependency)              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_charmmR1_bigger_box_20nm_with_Lysines
  15858313     20_pq_with_Lys_CR1   RUNNING    tcn[549,594]              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_charmmR1_bigger_box_20nm_with_Lysines

  Dry-run (no changes):
  scancel  15858313
  scancel  15858314
  ```
  </details>
- `smartcancel --contains KEYWORD` - if you want to cancel all jobs which has a keyword in common:
  <details>
  <summary>example</summary>

  ```bash
  [ponck1@int4 20_pq_amberR1_bigger_box_20nm_with_Lysines]$ smartcancel --contains 20_pq_with_Lys --dry-run
  Jobs to cancel
  JobID        JobName              State      Reason                    WorkDir
  15858563     20_pq_with_Lys_AR1   PENDING    (Dependency)              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_amberR1_bigger_box_20nm_with_Lysines
  15858314     20_pq_with_Lys_CR1   PENDING    (Dependency)              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_charmmR1_bigger_box_20nm_with_Lysines
  15858313     20_pq_with_Lys_CR1   RUNNING    tcn[549,594]              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_charmmR1_bigger_box_20nm_with_Lysines
  15858562     20_pq_with_Lys_AR1   RUNNING    tcn[743-744]              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_amberR1_bigger_box_20nm_with_Lysines

  Dry-run (no changes):
  scancel  15858313
  scancel  15858314
  scancel  15858562
  ```
  </details>
- `printf "ALL YOUR KEYWORDS SEPARATED BY A NEW LINE" | smartcancel --contains-from-stdin` - if you want to cancel all jobs using multiple keywords which are supplied through stdin.

  The keywords should be separated by a new line, even the last keyword should be preceded by a new line.
  <details>
  <summary>example 1</summary>

  ```bash
  [ponck1@int4 20_pq_amberR1_bigger_box_20nm_with_Lysines]$ printf "20_pq\npex13\n" | smartcancel --contains-from-stdin --dry-run
  Jobs to cancel
  JobID        JobName              State      Reason                    WorkDir
  15858563     20_pq_with_Lys_AR1   PENDING    (Dependency)              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_amberR1_bigger_box_20nm_with_Lysines
  15858314     20_pq_with_Lys_CR1   PENDING    (Dependency)              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_charmmR1_bigger_box_20nm_with_Lysines
  15819623     pex13_nterminal_10copies RUNNING    tcn[1086-1089,1101]       /gpfs/work3/0/ugc20675/Vasista/postdoc/peroxisomes/Nterminal/10molecules/R1
  15858313     20_pq_with_Lys_CR1   RUNNING    tcn[549,594]              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_charmmR1_bigger_box_20nm_with_Lysines
  15858562     20_pq_with_Lys_AR1   RUNNING    tcn[743-744]              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_amberR1_bigger_box_20nm_with_Lysines

  Dry-run (no changes):
  scancel  15819623
  scancel  15858313
  scancel  15858314
  scancel  15858562
  scancel  15858563
  ```
  </details>

  <details>
  <summary>example 2</summary>

  ```bash
  [ponck1@int4 20_pq_amberR1_bigger_box_20nm_with_Lysines]$ printf '%s\n' '20_pq_with_Lys_CR' '20_pq_with_Lys_CR' 'pex13_nterminal'| smartcancel --contains-from-stdin --dry-run
  Jobs to cancel
  JobID        JobName              State      Reason                    WorkDir
  15858314     20_pq_with_Lys_CR1   PENDING    (Dependency)              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_charmmR1_bigger_box_20nm_with_Lysines
  15819623     pex13_nterminal_10copies RUNNING    tcn[1086-1089,1101]       /gpfs/work3/0/ugc20675/Vasista/postdoc/peroxisomes/Nterminal/10molecules/R1
  15858313     20_pq_with_Lys_CR1   RUNNING    tcn[549,594]              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_charmmR1_bigger_box_20nm_with_Lysines

  Dry-run (no changes):
  scancel  15819623
  scancel  15858313
  scancel  15858314
  ```
  </details>
- `smartcancel --state STATE/REASON` -  if you want to cancel the jobs based on which state they are in, or what reason they have in the `squeue` output.

  As this flag accepts STATE/REASON, you can pass RUNNING or DEPENDENCY as arguments to the flag, which will be used to sorting the jobs.
  <details>
  <summary>example 1</summary>

  ```bash
  [ponck1@int4 20_pq_amberR1_bigger_box_20nm_with_Lysines]$ smartcancel --state dependency  --dry-run
  Jobs to cancel
  JobID        JobName              State      Reason                    WorkDir
  15858563     20_pq_with_Lys_AR1   PENDING    (Dependency)              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_amberR1_bigger_box_20nm_with_Lysines
  15858314     20_pq_with_Lys_CR1   PENDING    (Dependency)              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_charmmR1_bigger_box_20nm_with_Lysines

  Dry-run (no changes):
  scancel  15858314
  scancel  15858563
  ```
  </details>

  <details>
  <summary>example 2</summary>

  ```bash
  [ponck1@int4 20_pq_amberR1_bigger_box_20nm_with_Lysines]$ smartcancel --state running  --dry-run
  Jobs to cancel
  JobID        JobName              State      Reason                    WorkDir
  15819623     pex13_nterminal_10copies RUNNING    tcn[1086-1089,1101]       /gpfs/work3/0/ugc20675/Vasista/postdoc/peroxisomes/Nterminal/10molecules/R1
  15858313     20_pq_with_Lys_CR1   RUNNING    tcn[549,594]              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_charmmR1_bigger_box_20nm_with_Lysines
  15858562     20_pq_with_Lys_AR1   RUNNING    tcn[743-744]              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_amberR1_bigger_box_20nm_with_Lysines
  15819552     Q44_c2_3_restart1    RUNNING    tcn[1099-1100]            /gpfs/work3/0/ugc20675/Martin/sims_Q44_charm/Q44_c2_3_restart1
  15819484     Q44_c2_2_restart1    RUNNING    tcn[558,1179]             /gpfs/work3/0/ugc20675/Martin/sims_Q44_charm/Q44_c2_2_restart1
  15819331     Q44_c2_1_restart1    RUNNING    tcn[1024-1025]            /gpfs/work3/0/ugc20675/Martin/sims_Q44_charm/Q44_c2_1_restart1

  Dry-run (no changes):
  scancel  15819331
  scancel  15819484
  scancel  15819552
  scancel  15819623
  scancel  15858313
  scancel  15858562
  ```
  </details>
- `smartcancel --partition PARTITION` - if you want to cancel all the jobs on a specific partition:
  <details>
  <summary>example</summary>

  ```bash
  [ponck1@int4 20_pq_amberR1_bigger_box_20nm_with_Lysines]$ smartcancel --partition genoa  --dry-run
  Jobs to cancel
  JobID        JobName              State      Reason                    WorkDir
  15858563     20_pq_with_Lys_AR1   PENDING    (Dependency)              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_amberR1_bigger_box_20nm_with_Lysines
  15858314     20_pq_with_Lys_CR1   PENDING    (Dependency)              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_charmmR1_bigger_box_20nm_with_Lysines
  15819623     pex13_nterminal_10copies RUNNING    tcn[1086-1089,1101]       /gpfs/work3/0/ugc20675/Vasista/postdoc/peroxisomes/Nterminal/10molecules/R1
  15858313     20_pq_with_Lys_CR1   RUNNING    tcn[549,594]              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_charmmR1_bigger_box_20nm_with_Lysines
  15858562     20_pq_with_Lys_AR1   RUNNING    tcn[743-744]              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_amberR1_bigger_box_20nm_with_Lysines
  15819552     Q44_c2_3_restart1    RUNNING    tcn[1099-1100]            /gpfs/work3/0/ugc20675/Martin/sims_Q44_charm/Q44_c2_3_restart1
  15819484     Q44_c2_2_restart1    RUNNING    tcn[558,1179]             /gpfs/work3/0/ugc20675/Martin/sims_Q44_charm/Q44_c2_2_restart1
  15819331     Q44_c2_1_restart1    RUNNING    tcn[1024-1025]            /gpfs/work3/0/ugc20675/Martin/sims_Q44_charm/Q44_c2_1_restart1

  Dry-run (no changes):
  scancel  15819331
  scancel  15819484
  scancel  15819552
  scancel  15819623
  scancel  15858313
  scancel  15858314
  scancel  15858562
  scancel  15858563
  ```
  </details>
- `smartcancel --partition PARTITION --state STATE` - if you want to apply multiple filters on the `squeue` to filter the jobs you want to cancel:
  <details>
  <summary>example</summary>

  ```bash
  [ponck1@int4 20_pq_amberR1_bigger_box_20nm_with_Lysines]$ smartcancel --partition genoa  --state running --dry-run
  Jobs to cancel
  JobID        JobName              State      Reason                    WorkDir
  15819623     pex13_nterminal_10copies RUNNING    tcn[1086-1089,1101]       /gpfs/work3/0/ugc20675/Vasista/postdoc/peroxisomes/Nterminal/10molecules/R1
  15858313     20_pq_with_Lys_CR1   RUNNING    tcn[549,594]              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_charmmR1_bigger_box_20nm_with_Lysines
  15858562     20_pq_with_Lys_AR1   RUNNING    tcn[743-744]              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_amberR1_bigger_box_20nm_with_Lysines
  15819552     Q44_c2_3_restart1    RUNNING    tcn[1099-1100]            /gpfs/work3/0/ugc20675/Martin/sims_Q44_charm/Q44_c2_3_restart1
  15819484     Q44_c2_2_restart1    RUNNING    tcn[558,1179]             /gpfs/work3/0/ugc20675/Martin/sims_Q44_charm/Q44_c2_2_restart1
  15819331     Q44_c2_1_restart1    RUNNING    tcn[1024-1025]            /gpfs/work3/0/ugc20675/Martin/sims_Q44_charm/Q44_c2_1_restart1

  Dry-run (no changes):
  scancel  15819331
  scancel  15819484
  scancel  15819552
  scancel  15819623
  scancel  15858313
  scancel  15858562
  ```
  </details>
