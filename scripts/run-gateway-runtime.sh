#!/usr/bin/env bash
set -euo pipefail

runtime_bin=${1:?usage: run-gateway-runtime.sh <ohayess-runtime> <gateway-host> [interface] [bus]}
gateway_bin=${2:?usage: run-gateway-runtime.sh <ohayess-runtime> <gateway-host> [interface] [bus]}
interface=${3:-${OAS_CAN_INTERFACE:-can0}}
bus=${4:-${OAS_CAN_BUS:-0}}
viewer_bin=${OAS_VIEWER_BIN:-}
viewer_address=${OAS_VIEWER_ADDRESS:-127.0.0.1:8080}
maximum_age_ms=${OAS_MAXIMUM_AGE_MS:-500}
initial_backoff=${OAS_RECONNECT_INITIAL_BACKOFF_SECONDS:-1}
maximum_backoff=${OAS_RECONNECT_MAX_BACKOFF_SECONDS:-5}
stable_seconds=${OAS_RECONNECT_STABLE_SECONDS:-30}
gateway_pid=""
runtime_pid=""
fanout_pid=""
viewer_pid=""
temp_dir=$(mktemp -d)
snapshot_pipe="$temp_dir/snapshots"
runtime_pipe="$temp_dir/runtime"
mkfifo "$snapshot_pipe"
mkfifo "$runtime_pipe"
if [[ -n $viewer_bin ]]; then
  viewer_pipe="$temp_dir/viewer"
  mkfifo "$viewer_pipe"
fi

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
  for pid in "$gateway_pid" "$fanout_pid" "$runtime_pid" "$viewer_pid"; do
    [[ -n $pid ]] && kill "$pid" 2>/dev/null || true
  done
  wait "$gateway_pid" 2>/dev/null || true
  wait "$fanout_pid" 2>/dev/null || true
  wait "$runtime_pid" 2>/dev/null || true
  wait "$viewer_pid" 2>/dev/null || true
  [[ -n ${OAS_GATEWAY_PID_FILE:-} ]] && rm -f "$OAS_GATEWAY_PID_FILE"
  rm -f "$snapshot_pipe" "$runtime_pipe" "${viewer_pipe:-}"
  rmdir "$temp_dir"
  exit 0
}
trap stop INT TERM

backoff=$initial_backoff
while true; do
  started_at=$SECONDS
  "$runtime_bin" "$maximum_age_ms" <"$runtime_pipe" &
  runtime_pid=$!
  pids=("$runtime_pid")

  if [[ -n $viewer_bin ]]; then
    "$viewer_bin" "$viewer_address" "$maximum_age_ms" <"$viewer_pipe" &
    viewer_pid=$!
    pids+=("$viewer_pid")
    tee "$runtime_pipe" "$viewer_pipe" <"$snapshot_pipe" >/dev/null &
  else
    tee "$runtime_pipe" <"$snapshot_pipe" >/dev/null &
  fi
  fanout_pid=$!
  pids+=("$fanout_pid")

  "$gateway_bin" "$interface" "$bus" >"$snapshot_pipe" &
  gateway_pid=$!
  pids+=("$gateway_pid")
  [[ -n ${OAS_GATEWAY_PID_FILE:-} ]] && printf '%s\n' "$gateway_pid" >"$OAS_GATEWAY_PID_FILE"

  wait -n "${pids[@]}" || true
  for pid in "${pids[@]}"; do
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
