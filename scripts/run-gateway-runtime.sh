#!/usr/bin/env bash
set -euo pipefail

runtime_bin=${1:?usage: run-gateway-runtime.sh <ohayess-runtime> <gateway-host> [interface] [bus]}
gateway_bin=${2:?usage: run-gateway-runtime.sh <ohayess-runtime> <gateway-host> [interface] [bus]}
interface=${3:-${OAS_CAN_INTERFACE:-can0}}
bus=${4:-${OAS_CAN_BUS:-0}}
maximum_age_ms=${OAS_MAXIMUM_AGE_MS:-500}
initial_backoff=${OAS_RECONNECT_INITIAL_BACKOFF_SECONDS:-1}
maximum_backoff=${OAS_RECONNECT_MAX_BACKOFF_SECONDS:-5}
stable_seconds=${OAS_RECONNECT_STABLE_SECONDS:-30}
gateway_pid=""
runtime_pid=""
temp_dir=$(mktemp -d)
snapshot_pipe="$temp_dir/snapshots"
mkfifo "$snapshot_pipe"

for value in "$initial_backoff" "$maximum_backoff" "$stable_seconds"; do
  [[ $value =~ ^[0-9]+$ ]] || {
    echo "backoff settings must be non-negative integers" >&2
    exit 2
  }
done
(( initial_backoff > 0 && maximum_backoff >= initial_backoff )) || {
  echo "invalid reconnect backoff range" >&2
  exit 2
}

stop() {
  for pid in "$gateway_pid" "$runtime_pid"; do
    [[ -n $pid ]] && kill "$pid" 2>/dev/null || true
  done
  wait "$gateway_pid" 2>/dev/null || true
  wait "$runtime_pid" 2>/dev/null || true
  [[ -n ${OAS_GATEWAY_PID_FILE:-} ]] && rm -f "$OAS_GATEWAY_PID_FILE"
  rm -f "$snapshot_pipe"
  rmdir "$temp_dir"
  exit 0
}
trap stop INT TERM

backoff=$initial_backoff
while true; do
  started_at=$SECONDS
  "$gateway_bin" "$interface" "$bus" >"$snapshot_pipe" &
  gateway_pid=$!
  [[ -n ${OAS_GATEWAY_PID_FILE:-} ]] && printf '%s\n' "$gateway_pid" >"$OAS_GATEWAY_PID_FILE"
  "$runtime_bin" "$maximum_age_ms" <"$snapshot_pipe" &
  runtime_pid=$!

  wait -n "$gateway_pid" "$runtime_pid" || true
  for pid in "$gateway_pid" "$runtime_pid"; do
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  done

  if (( SECONDS - started_at >= stable_seconds )); then
    backoff=$initial_backoff
  fi
  sleep "$backoff"
  (( backoff < maximum_backoff )) && backoff=$((backoff * 2))
  (( backoff > maximum_backoff )) && backoff=$maximum_backoff
done
