#!/usr/bin/env bash

# slurm.sh - Slurm library module
# Return lines: JobID|JobName|State|WorkDir|Elapsed|StartTime|Reason|Partition|TimeLeft for a user (default: current)
slurm::squeue_lines() {
  require_cmd squeue
  local state="${1:-}" user="${2:-$(current_user)}"
  local args=(-h -o "%i|%j|%T|%Z|%M|%S|%R|%P|%L" -u "$user")
  [[ -n "$state" ]] && args+=(-t "$state")
  log_run_capture "slurm::squeue_lines" squeue "${args[@]}"
}

# Return the normal nine job fields plus a tenth Dependency field. This keeps
# job and dependency data in one scheduler snapshot without changing the
# canonical nine-field records used by filters.
slurm::squeue_lines_with_dependencies() {
  require_cmd squeue
  local state="${1:-}" user="${2:-$(current_user)}"
  local args=(-h -o "%i|%j|%T|%Z|%M|%S|%R|%P|%L|%E" -u "$user")
  [[ -n "$state" ]] && args+=(-t "$state")
  log_run_capture "slurm::squeue_lines_with_dependencies" squeue "${args[@]}"
}

# Expand newline-separated target IDs through a JobID|Dependency snapshot.
# The fixed-point traversal is entirely local and preserves recursive behavior.
slurm::expand_with_dependents() {
  local dependency_lines="$1" targets="$2"
  awk -F'|' '
    NR == FNR { if ($1 != "") selected[$1]=1; next }
    NF >= 2 {
      count++
      ids[count]=$1
      dependencies[count]=$2
    }
    END {
      changed=1
      while (changed) {
        changed=0
        for (i=1; i<=count; i++) {
          if (ids[i] in selected) continue
          dependency=dependencies[i]
          gsub(/\([^)]*\)/, "", dependency)
          gsub(/[,:;?]/, " ", dependency)
          part_count=split(dependency, parts, /[[:space:]]+/)
          for (part=1; part<=part_count; part++) {
            if (parts[part] in selected) {
              selected[ids[i]]=1
              changed=1
              break
            }
          }
        }
      }
      for (id in selected) print id
    }
  ' <(printf '%s\n' "$targets") <(printf '%s\n' "$dependency_lines") | sort -u
}

# squeue lines for the given job names (current user).
slurm::squeue_by_job_names() {
  require_cmd squeue
  local user="${1:-$(current_user)}"; shift || true

  # Collect job names either from args or stdin into a temp file
  local tmpnames
  tmpnames="$(mktemp)" || { echo "mktemp failed" >&2; return 1; }

  if [[ $# -gt 0 ]]; then
    printf '%s\n' "$@" >"$tmpnames"
  else
    # read from stdin
    # shellcheck disable=SC2162
    while IFS= read -r n; do
      [[ -n "$n" ]] && printf '%s\n' "$n" >>"$tmpnames"
    done
  fi

  # If no names provided, nothing to filter
  if [[ ! -s "$tmpnames" ]]; then
    rm -f "$tmpnames"
    return 0
  fi

  # Two-file trick:
  #  - First input (tmpnames): build set[name]
  #  - Second input (squeue output): print rows where JobName ($2) is in set
  local rows
  rows="$(log_run_capture "slurm::squeue_by_job_names" squeue \
            -h -o "%i|%j|%T|%Z|%M|%S|%R|%P|%L" -u "$user")"
  awk -F'|' 'NR==FNR { set[$1]; next } $2 in set' "$tmpnames" <<<"$rows"

  local rc=$?
  rm -f "$tmpnames"
  return $rc
}
# Convenience: return JobIDs only for the given names
slurm::job_ids_by_job_names() {
  slurm::squeue_by_job_names "$(current_user)" "$@" | cut -d'|' -f1 | sed '/^$/d' | sort -u
}
