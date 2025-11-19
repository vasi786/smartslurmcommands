#!/usr/bin/env bash
# shellcheck disable=SC2034
# stops complaining about the unusage of the FILTERS (pre-commit phase)
args::parse_state() {
    local var
    val="$(tr '[:upper:]' '[:lower:]' <<<"$1")"

    case "$val" in
        dependency|dep|deps)
            STATE_FILTER="PENDING"
            REASON_FILTER="Dependency"
            ;;

        pending|running|suspended|completed|cancelled|failed|timeout|node_fail|preempted|boot_fail|deadline|out_of_memory|completing|configuring|resizing|resv_del_hold|requeued|requeue_fed|requeue_hold|revoked|signaling|special_exit|stage_out|stopped)
            STATE_FILTER="$(tr '[:lower:]' '[:upper:]' <<<"$val")"
            ;;

        *)
            die 2 "Unknown state: $val"
            ;;
    esac
}
