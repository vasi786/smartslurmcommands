# Design
- One binary per tool (no central dispatcher)
- Shared Bash libs in `lib/`
- Queue records retain nine fields through every filter: `JobID|JobName|State|WorkDir|Elapsed|StartTime|Reason|Partition|TimeLeft`.
- Dependency snapshots append `Dependency` as a tenth field and strip it back off before normal filtering.
- `smartcancel` computes one final cancellation set before preview, confirmation, dry-run, or execution.
