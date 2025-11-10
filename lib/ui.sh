#!/usr/bin/env bash
# ui.sh — lightweight interactive helpers (tty-safe, POSIX-friendly)

# ui::pick_jobnames
# Prompts the user to choose one or more job names.
# - args: list of names to choose from
# - stdout: newline-separated chosen names
# - exit codes: 0 ok, 2 invalid input
# Behavior:
# - If not a TTY (piped/cron), selects ALL by default.
# - Supports "a" for all (default), single index "2", or comma list "1,3".
ui::pick_jobnames() {
  local names=("$@")
  local n="${#names[@]}"
  (( n > 0 )) || return 0

  # Non-interactive: return all
  if [[ ! -t 0 || ! -t 1 ]]; then
    printf '%s\n' "${names[@]}"
    return 0
  fi

  printf 'Found %d job name(s):\n' "$n" 1>&2
  local i
  for ((i=0; i<n; i++)); do
    printf '  %2d) %s\n' "$((i+1))" "${names[$i]}" 1>&2
  done
  printf 'Choose one by number, a comma list like "1,3", or press Enter for all [a]: ' 1>&2
  local sel; IFS= read -r sel

  # default: all
  if [[ -z "$sel" || "$sel" == [aA] ]]; then
    printf '%s\n' "${names[@]}"
    return 0
  fi

  # validate "1" or "1,3,5"
  if [[ "$sel" =~ ^[0-9]+([,][0-9]+)*$ ]]; then
    local out=() k; IFS=',' read -r -a ks <<< "$sel"
    for k in "${ks[@]}"; do
      if (( k>=1 && k<=n )); then
        out+=("${names[$((k-1))]}")
      else
        printf 'Invalid choice: %s (valid 1..%d)\n' "$k" "$n" 1>&2
        return 2
      fi
    done
    printf '%s\n' "${out[@]}"
    return 0
  fi

  printf 'Invalid input.\n' 1>&2
  return 2
}

