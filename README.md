# smartslurmcommands (ssc)

After four and half years of PhD in computational biophysics (currently a postdoc), with a lot of usage of HPC, the biggest issue I faced is the
effort to cancel jobs. For example, I submit a simulation, and realized that I have missed a parameter and want to cancel that
job among hundreds of jobs I am running at the same time and finding this job ID is a challenge. I always thought of adding my own alias which does this
for me smartly. You could ask, why not use the job name. In my case the job name is a 32 character random string and
I would like to minimize the operations to cancel the latest job which I submitted a minute ago and was surprised that this functionality doesn't exist natively or someone didn't develop a tool
for these use cases. Thus, I  took myself the challenge (fed it to GPT mostly) and wrote this simple wrapper commands on top of native slurm commands which are used by
daily user to make things smarter and efficient in daily world of a HPC user.
