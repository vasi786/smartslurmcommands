# Design
- One binary per tool (no central dispatcher)
- Shared Bash libs in `lib/`
- Queue records retain eight fields through every filter: `JobID|JobName|State|WorkDir|Elapsed|StartTime|Reason|Partition`.
- `smartcancel` computes one final cancellation set before preview, confirmation, dry-run, or execution.
