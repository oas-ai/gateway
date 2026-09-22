#!/usr/bin/env bash
set -euo pipefail

runtime_bin=${1:?usage: e2e-vcan.sh <ohayess-runtime> [gateway-host]}
gateway_bin=${2:-target/debug/oas-gateway-host}
temp_dir=$(mktemp -d)
snapshot_pipe="$temp_dir/snapshots"
runtime_log="$temp_dir/runtime.log"
gateway_pid=""
runtime_pid=""

cleanup() {
  if [[ -n "$runtime_pid" ]]; then
    kill "$runtime_pid" 2>/dev/null || true
    wait "$runtime_pid" 2>/dev/null || true
  fi
  if [[ -n "$gateway_pid" ]]; then
    kill "$gateway_pid" 2>/dev/null || true
    wait "$gateway_pid" 2>/dev/null || true
  fi
  rm -f "$snapshot_pipe" "$runtime_log"
  rmdir "$temp_dir"
}
trap cleanup EXIT

mkfifo "$snapshot_pipe"
"$gateway_bin" vcan0 0 >"$snapshot_pipe" &
gateway_pid=$!
"$runtime_bin" 2000 <"$snapshot_pipe" 2>"$runtime_log" &
runtime_pid=$!

for _ in {1..20}; do
  cansend vcan0 4F1#00A00000
  cansend vcan0 2B0#8403000000
  cansend vcan0 394#000000007C440000
  cansend vcan0 367#0000000000000000
  cansend vcan0 386#0020001000080004
  cansend vcan0 389#0000000001000000
  if grep -Eq 'speed_mps=Some\(22\.222.*acceleration_mps2=Some\(1\.25\).*steering_angle_rad=Some\(1\.570796.*brake_pressed=Some\(true\).*fresh=true' "$runtime_log"; then
    exit 0
  fi
  sleep 0.25
done

cat "$runtime_log" >&2
exit 1
