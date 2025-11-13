# smartslurmcommands (ssc)

After four and half years of PhD in computational biophysics (currently a postdoc), with a lot of usage of HPC, the biggest issue I faced is the
effort to cancel jobs. For example, I submit a simulation, and realized that I have missed a parameter and want to cancel that
job among hundreds of jobs I am running at the same time and finding this job ID is a challenge. I always thought of adding my own alias which does this
for me smartly. You could ask, why not use the job name. In my case the job name is a 32 character random string and
I would like to minimize the operations to cancel the latest job which I submitted an hour ago and was surprised that this functionality doesn't exist natively or someone didn't develop a tool
for these use cases. Thus, I took myself the challenge (fed it to GPT mostly) and wrote this simple wrapper commands on top of native slurm commands which are used by
daily user to make things smarter and efficient in world of a HPC user.

## mqpwd (my-squeue-pwd)
This command gets the jobs which are related to the current directory which you are in (if no args are passed).
If you pass a path, then the command will fetch the jobs relating to that working directory.
```
[user@int4 20_pq_charmmR1_bigger_box_20nm_with_Lysines]$ mqpwd
    JOBID  PARTITION  NAME                                    USER ST        TIME [ TIME_LEFT] MIN_M  CPUS - NODES NODELIST(REASON)
 15858314      genoa  20_pq_with_Lys_CR1                    ponck1 PD        0:00 [5-00:00:00]  100G   384 - 2     (Dependency)
 15858313      genoa  20_pq_with_Lys_CR1                    ponck1  R  3-05:08:38 [1-18:51:22]  100G   384 - 2     tcn[549,594]

[user@int4 20_pq_charmmR1_bigger_box_20nm_with_Lysines]$ mqpwd ../20_pq_amberR1_bigger_box_20nm_with_Lysines/
    JOBID  PARTITION  NAME                                    USER ST        TIME [ TIME_LEFT] MIN_M  CPUS - NODES NODELIST(REASON)
 15858563      genoa  20_pq_with_Lys_AR1                    ponck1 PD        0:00 [5-00:00:00]  100G   384 - 2     (Dependency)
 15858562      genoa  20_pq_with_Lys_AR1                    ponck1  R  3-04:23:14 [1-19:36:46]  100G   384 - 2     tcn[743-744]
```

