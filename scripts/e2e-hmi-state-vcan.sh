#!/usr/bin/env bash
set -euo pipefail

runtime_bin=${1:?usage: e2e-hmi-state-vcan.sh <ohayess-runtime> <hmi-state-probe> [gateway-host] [supervisor]}
probe_bin=${2:?usage: e2e-hmi-state-vcan.sh <ohayess-runtime> <hmi-state-probe> [gateway-host] [supervisor]}
gateway_bin=${3:-target/debug/oas-gateway-host}
supervisor=${4:-./scripts/run-gateway-runtime.sh}
source "$(dirname "$0")/fixtures/palisade-2020-diagnostics.sh"
temp_dir=$(mktemp -d)
hmi_stream="$temp_dir/hmi-state"
output="$temp_dir/output"
mkfifo "$hmi_stream"
probe_pid=""
supervisor_pid=""

cleanup() {
  [[ -n $probe_pid ]] && kill "$probe_pid" 2>/dev/null || true
  [[ -n $supervisor_pid ]] && kill "$supervisor_pid" 2>/dev/null || true
  [[ -n $probe_pid ]] && wait "$probe_pid" 2>/dev/null || true
  [[ -n $supervisor_pid ]] && wait "$supervisor_pid" 2>/dev/null || true
  rm -rf "$temp_dir"
}
trap cleanup EXIT

"$probe_bin" <"$hmi_stream" >"$output" &
probe_pid=$!
OAS_HMI_STREAM="$hmi_stream" "$supervisor" "$runtime_bin" "$gateway_bin" vcan0 0 &
supervisor_pid=$!
sleep 0.2
send_palisade_2020_frames

for _ in {1..30}; do
  kill -0 "$probe_pid" 2>/dev/null || break
  sleep 0.1
done
wait "$probe_pid"
grep -Eq 'freshness=Fresh media=Locked reason=vehicle_in_motion diagnostics=Allowed controls=Unavailable speed=Some\(22\.222' "$output"
