# Performance benchmarks

Run the reproducible mocked-Slurm benchmark from the repository root:

```bash
scripts/benchmark.sh
```

The default is three samples for each scenario at 10, 100, 1,000, 5,000, and 10,000 jobs.
The reported time is the median sample.
Override the run count or sizes when doing a quick check:

```bash
BENCH_RUNS=1 BENCH_SIZES="100 1000" scripts/benchmark.sh
```

`baseline.csv` records commit `9929994` before performance changes.
`optimized.csv` records the optimized implementation on the same machine and mocked data.

The harness records expensive scheduler-command counts separately from timing.
It never contacts a live Slurm cluster and all `smartcancel` scenarios use `--dry-run`.
