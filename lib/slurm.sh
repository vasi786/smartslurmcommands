#!/usr/bin/env bash
# slurm.sh - Slurm library module
# Return lines: JobID|JobName|State|WorkDir|Elapsed|StartTime for a user (default: current)
slurm::squeue_lines() {
  require_cmd squeue
  local state="${1:-}" user="${2:-$(current_user)}"
  local args=(-h -o "%i|%j|%T|%Z|%M|%S|%R|%P" -u "$user")
  [[ -n "$state" ]] && args+=(-t "$state")
  squeue "${args[@]}"
}

# Pick the "latest" line by StartTime (field 6), fallback to highest JobID
slurm::pick_latest_line() {
  awk -F'|' '
    BEGIN { bestid=0; bestS=""; have=0 }
    {
      id=$1; S=$6;
      if (S ~ /[0-9]/) {
        if (!have || S > bestS) { bestS=S; bestid=id; best=$0; have=1 }
      } else {
        if (!have || id+0 > bestid+0) { bestid=id; best=$0; have=1 }
      }
    }
    END { if (have) print best }
  '
}

# Collect jobs that depend on any of the target IDs (reverse dependency walk).
# Args:
#   $1 = squeue cache lines "JobID|JobName|State|WorkDir|Elapsed|StartTime"
#   $2 = newline-separated target job IDs
slurm::collect_dependents() {
  require_cmd scontrol
  local squeue_cache="$1" targets="$2"
  local new=""
  # all job ids from cache
  while IFS='|' read -r jid _; do
    [[ -z "$jid" ]] && continue
    # Dependency=afterok:123,456;afterany:789
    local dep
    dep="$(scontrol show job "$jid" 2>/dev/null | awk -F= '/Dependency=/{print $2}' | tr -d ' ')"
    [[ -z "$dep" ]] && continue
    # Normalize separators to newlines for easy matching
    local flat="${dep//[,;:]/$'\n'}"
    while read -r tid; do
      [[ -z "$tid" ]] && continue
      if grep -qx "$tid" <<<"$flat"; then
        new+="$jid"$'\n'
        break
      fi
    done <<< "$targets"
  done <<< "$squeue_cache"

  printf "%s" "$new" | sed '/^$/d' | sort -u
}
# add dependency jobs to the target list for canceling
expand_with_dependents() {
  local cache="$1" ids="$2" added next
  while :; do
    added="$(slurm::collect_dependents "$cache" "$ids")"
    next="$(printf "%s\n%s\n" "$ids" "$added" | sed '/^$/d' | sort -u)"
    [[ "$next" == "$ids" ]] && break
    ids="$next"
  done
  printf "%s\n" "$ids"
}

# Return newline-separated job names declared in #SBATCH directives within *.sh in DIR.
# Handles:
#   #SBATCH --job-name=NAME
#   #SBATCH --job-name NAME
#   #SBATCH --job-name="name with spaces"
slurm::job_names_from_dir() {
  local dir="${1:-$PWD}"
  [[ -d "$dir" ]] || { echo "error: directory not found: $dir" >&2; return 2; }

  # Find scripts (top-level only)
  mapfile -t files < <(find "$dir" -maxdepth 1 -type f -name "*.sh" 2>/dev/null | sort)
  [[ ${#files[@]} -gt 0 ]] || return 0  # no scripts -> no names

  # Grep SBATCH job-name lines and extract the value
  # We strip leading/trailing spaces and optional quotes.
  grep -hE '^[[:space:]]*#SBATCH[[:space:]]+--job-name(=|[[:space:]])' "${files[@]}" 2>/dev/null \
  | sed -E 's/^[[:space:]]*#SBATCH[[:space:]]+--job-name[[:space:]]*=?[[:space:]]*//; s/[[:space:]]+$//' \
  | sed -E 's/^"(.*)"$/\1/; s/'"'"'(.*)'"'"'$/\1/' \
  | awk 'NF' \
  | sort -u
}

# squeue lines (JobID|JobName|State|WorkDir|Elapsed|StartTime) for given job names (current user).
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
  squeue -h -o "%i|%j|%T|%Z|%M|%S|%R" -u "$user" \
  | awk -F'|' 'NR==FNR { set[$1]; next } $2 in set' "$tmpnames" -

  local rc=$?
  rm -f "$tmpnames"
  return $rc
}
# Convenience: return JobIDs only for the given names
slurm::job_ids_by_job_names() {
  slurm::squeue_by_job_names "$(current_user)" "$@" | cut -d'|' -f1 | sed '/^$/d' | sort -u
}

