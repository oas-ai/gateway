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
  if grep -q 'speed_mps=Some(22.222' "$runtime_log" && grep -q 'fresh=true' "$runtime_log"; then
    exit 0
  fi
  sleep 0.25
done

cat "$runtime_log" >&2
exit 1
