# smartcancel & mq – Example Commands and Outputs

Below are example commands for `mq` and `smartcancel`, each with a short description and a collapsible section containing the full example output.

---

## 1. List all your Slurm jobs

To list all your current Slurm jobs, execute:

```
mq
<details> <summary>Show example output</summary>


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
</details>

2. Preview cancelling jobs from the current directory
To preview which jobs associated with the current directory would be cancelled, execute:



smartcancel --this-dir --dry-run
<details> <summary>Show example output</summary>


[user@int4 20_pq_amberR1_bigger_box_20nm_with_Lysines]$ smartcancel --this-dir --dry-run
Jobs to cancel
JobID        JobName              State      Reason                    WorkDir
15858563     20_pq_with_Lys_AR1   PENDING    (Dependency)              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_amberR1_bigger_box_20nm_with_Lysines
15858562     20_pq_with_Lys_AR1   RUNNING    tcn[743-744]              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_amberR1_bigger_box_20nm_with_Lysines

Dry-run (no changes):
scancel  15858562
scancel  15858563
</details>
3. Preview cancelling only the latest job in the current directory
To preview cancelling only the latest job for the current directory, execute:



smartcancel --this-dir --latest --dry-run
<details> <summary>Show example output</summary>


[user@int4 20_pq_amberR1_bigger_box_20nm_with_Lysines]$ smartcancel --this-dir --latest --dry-run
Jobs to cancel
JobID        JobName              State      Reason                    WorkDir
15858562     20_pq_with_Lys_AR1   RUNNING    tcn[743-744]              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_amberR1_bigger_box_20nm_with_Lysines

Dry-run (no changes):
scancel  15858562
</details>
4. Check for jobs in the current directory older than 240h
To preview cancellations for jobs older than 240 hours in the current directory, execute:



smartcancel --this-dir --older-than 240h --dry-run
<details> <summary>Show example output</summary>


[user@int4 20_pq_amberR1_bigger_box_20nm_with_Lysines]$ smartcancel --this-dir --older-than 240h --dry-run
info: No matching jobs.
</details>
5. Preview cancelling jobs in the current directory older than 40h
To preview cancellations for jobs older than 40 hours in the current directory, execute:



smartcancel --this-dir --older-than 40h --dry-run
<details> <summary>Show example output</summary>


[user@int4 20_pq_amberR1_bigger_box_20nm_with_Lysines]$ smartcancel --this-dir --older-than 40h --dry-run
Jobs to cancel
JobID        JobName              State      Reason                    WorkDir
15858562     20_pq_with_Lys_AR1   RUNNING    tcn[743-744]              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_amberR1_bigger_box_20nm_with_Lysines


Dry-run (no changes):
scancel  15858562
</details>
6. Preview cancelling old jobs from another directory
To preview cancellations for jobs older than 40 hours in a specified directory, execute:



smartcancel --dir ../20_pq_charmmR1_bigger_box_20nm_with_Lysines/ --older-than 40h --dry-run
<details> <summary>Show example output</summary>


[user@int4 20_pq_amberR1_bigger_box_20nm_with_Lysines]$ smartcancel --dir ../20_pq_charmmR1_bigger_box_20nm_with_Lysines/ --older-than 40h --dry-run
Jobs to cancel
JobID        JobName              State      Reason                    WorkDir
15858313     20_pq_with_Lys_CR1   RUNNING    tcn[549,594]              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_charmmR1_bigger_box_20nm_with_Lysines


Dry-run (no changes):
scancel  15858313
</details>
7. Check for very old jobs in another directory (none found)
To preview cancellations for jobs older than 240 hours in a specified directory, execute:



smartcancel --dir ../20_pq_charmmR1_bigger_box_20nm_with_Lysines/ --older-than 240h --dry-run
<details> <summary>Show example output</summary>


[user@int4 20_pq_amberR1_bigger_box_20nm_with_Lysines]$ smartcancel --dir ../20_pq_charmmR1_bigger_box_20nm_with_Lysines/ --older-than 240h --dry-run
info: No matching jobs.
</details>
8. Preview cancelling jobs by exact job name
To preview cancellations for jobs matching an exact name, execute:



smartcancel --name 20_pq_with_Lys_CR1 --dry-run
<details> <summary>Show example output</summary>


[user@int4 20_pq_amberR1_bigger_box_20nm_with_Lysines]$ smartcancel --name 20_pq_with_Lys_CR1 --dry-run
Jobs to cancel
JobID        JobName              State      Reason                    WorkDir
15858314     20_pq_with_Lys_CR1   PENDING    (Dependency)              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_charmmR1_bigger_box_20nm_with_Lysines
15858313     20_pq_with_Lys_CR1   RUNNING    tcn[549,594]              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_charmmR1_bigger_box_20nm_with_Lysines

Dry-run (no changes):
scancel  15858313
scancel  15858314
</details>
9. Preview cancelling jobs whose names contain a substring
To preview cancellations for jobs whose names contain a given substring, execute:



smartcancel --contains 20_pq_with_Lys --dry-run
<details> <summary>Show example output</summary>


[user@int4 20_pq_amberR1_bigger_box_20nm_with_Lysines]$ smartcancel --contains 20_pq_with_Lys --dry-run
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
</details>
10. Preview cancelling jobs whose names match any of multiple patterns from stdin
To preview cancellations for jobs whose names contain any of several patterns read from stdin, execute:



printf "20_pq\npex13\n" | smartcancel --contains-from-stdin --dry-run
<details> <summary>Show example output</summary>


[user@int4 20_pq_amberR1_bigger_box_20nm_with_Lysines]$ printf "20_pq\npex13\n" | smartcancel --contains-from-stdin --dry-run
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
</details>
11. Preview cancelling jobs using patterns from stdin with duplicates
To preview cancellations for jobs whose names match possibly duplicated patterns from stdin, execute:



printf '%s\n' '20_pq_with_Lys_CR' '20_pq_with_Lys_CR' 'pex13_nterminal' | smartcancel --contains-from-stdin --dry-run
<details> <summary>Show example output</summary>


[user@int4 20_pq_amberR1_bigger_box_20nm_with_Lysines]$ printf '%s\n' '20_pq_with_Lys_CR' '20_pq_with_Lys_CR' 'pex13_nterminal'| smartcancel --contains-from-stdin --dry-run
Jobs to cancel
JobID        JobName              State      Reason                    WorkDir
15858314     20_pq_with_Lys_CR1   PENDING    (Dependency)              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_charmmR1_bigger_box_20nm_with_Lysines
15819623     pex13_nterminal_10copies RUNNING    tcn[1086-1089,1101]       /gpfs/work3/0/ugc20675/Vasista/postdoc/peroxisomes/Nterminal/10molecules/R1
15858313     20_pq_with_Lys_CR1   RUNNING    tcn[549,594]              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_charmmR1_bigger_box_20nm_with_Lysines

Dry-run (no changes):
scancel  15819623
scancel  15858313
scancel  15858314
</details>
12. Preview cancelling jobs in a specific state: dependency (pending)
To preview cancellations for jobs in dependency-pending state, execute:



smartcancel --state dependency --dry-run
<details> <summary>Show example output</summary>


[user@int4 20_pq_amberR1_bigger_box_20nm_with_Lysines]$ smartcancel --state dependency  --dry-run
Jobs to cancel
JobID        JobName              State      Reason                    WorkDir
15858563     20_pq_with_Lys_AR1   PENDING    (Dependency)              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_amberR1_bigger_box_20nm_with_Lysines
15858314     20_pq_with_Lys_CR1   PENDING    (Dependency)              /gpfs/work3/0/ugc20675/Vasista/phd/20_pq_charmmR1_bigger_box_20nm_with_Lysines

Dry-run (no changes):
scancel  15858314
scancel  15858563
</details>
13. Preview cancelling jobs in a specific state: running
To preview cancellations for all running jobs, execute:



smartcancel --state running --dry-run
<details> <summary>Show example output</summary>


[user@int4 20_pq_amberR1_bigger_box_20nm_with_Lysines]$ smartcancel --state running  --dry-run
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
</details>
14. Preview cancelling jobs on a specific partition
To preview cancellations for all jobs on a given partition, execute:



smartcancel --partition genoa --dry-run
<details> <summary>Show example output</summary>


[user@int4 20_pq_amberR1_bigger_box_20nm_with_Lysines]$ smartcancel --partition genoa  --dry-run
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
</details>
15. Preview cancelling running jobs on a specific partition
To preview cancellations for all running jobs on a given partition, execute:



smartcancel --partition genoa --state running --dry-run
<details> <summary>Show example output</summary>


[user@int4 20_pq_amberR1_bigger_box_20nm_with_Lysines]$ smartcancel --partition genoa  --state running --dry-run
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
</details>
16. Preview cancelling the latest job overall
To preview cancelling your latest submitted job (regardless of directory), execute:



smartcancel --latest --dry-run
<details> <summary>Show example output</summary>


[user@int4 20_pq_amberR1_bigger_box_20nm_with_Lysines]$ smartcancel --latest --dry-run
Jobs to cancel
JobID        JobName              State      Reason                    WorkDir
15819623     pex13_nterminal_10copies RUNNING    tcn[1086-1089,1101]       /gpfs/work3/0/ugc20675/Vasista/postdoc/peroxisomes/Nterminal/10molecules/R1

Dry-run (no changes):
scancel  15819623
</details> ```
