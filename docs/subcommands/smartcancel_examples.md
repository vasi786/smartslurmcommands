# smartcancel & mq – Example Commands and Outputs

Below are example commands for `mq` and `smartcancel`, each with a short description and a collapsible section containing the full example output.

---

### 1. List all your Slurm jobs

To list all your current Slurm jobs, execute:
`mq` (which is not implemented in the current version)
<details>
<summary>Show example output</summary>

```bash
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
</details>
