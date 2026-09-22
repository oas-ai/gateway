#!/usr/bin/env bash
set -euo pipefail

runtime_bin=${1:?usage: e2e-recovery-vcan.sh <ohayess-runtime> [gateway-host] [supervisor]}
gateway_bin=${2:-target/debug/oas-gateway-host}
supervisor=${3:-./scripts/run-gateway-runtime.sh}
temp_dir=$(mktemp -d)
runtime_log="$temp_dir/runtime.log"
gateway_pid_file="$temp_dir/gateway.pid"
supervisor_pid=""

cleanup() {
  [[ -n $supervisor_pid ]] && kill "$supervisor_pid" 2>/dev/null || true
  [[ -n $supervisor_pid ]] && wait "$supervisor_pid" 2>/dev/null || true
  rm -f "$runtime_log" "$gateway_pid_file"
  rmdir "$temp_dir"
}
trap cleanup EXIT

OAS_GATEWAY_PID_FILE="$gateway_pid_file" "$supervisor" "$runtime_bin" "$gateway_bin" vcan0 0 \
  2>"$runtime_log" &
supervisor_pid=$!

for _ in {1..20}; do
  [[ -s $gateway_pid_file ]] && break
  sleep 0.1
done
old_gateway_pid=$(<"$gateway_pid_file")
kill -0 "$old_gateway_pid"

cansend vcan0 4F1#00A00000
cansend vcan0 2B0#8403000000
cansend vcan0 394#000000007C440000
cansend vcan0 367#0000000000000000
cansend vcan0 386#0020001000080004
cansend vcan0 389#0000000001000000
for _ in {1..20}; do
  grep -Eq 'speed_mps=Some\(22\.222.*acceleration_mps2=Some\(1\.25\).*steering_angle_rad=Some\(1\.570796.*brake_pressed=Some\(true\).*fresh=true' "$runtime_log" && break
  sleep 0.1
done
grep -Eq 'speed_mps=Some\(22\.222.*acceleration_mps2=Some\(1\.25\).*steering_angle_rad=Some\(1\.570796.*brake_pressed=Some\(true\).*fresh=true' "$runtime_log"

kill -TERM "$old_gateway_pid"
for _ in {1..40}; do
  new_gateway_pid=$(<"$gateway_pid_file")
  [[ $new_gateway_pid != "$old_gateway_pid" ]] && kill -0 "$new_gateway_pid" 2>/dev/null && break
  sleep 0.1
done
[[ $new_gateway_pid != "$old_gateway_pid" ]]
kill -0 "$new_gateway_pid"

cansend vcan0 4F1#00A00000
cansend vcan0 2B0#8403000000
cansend vcan0 394#000000007C440000
cansend vcan0 367#0000000000000000
cansend vcan0 386#0020001000080004
cansend vcan0 389#0000000001000000
for _ in {1..30}; do
  [[ $(grep -Ec 'speed_mps=Some\(22\.222.*acceleration_mps2=Some\(1\.25\).*steering_angle_rad=Some\(1\.570796.*brake_pressed=Some\(true\).*fresh=true' "$runtime_log") -ge 2 ]] && exit 0
  sleep 0.1
done
cat "$runtime_log" >&2
exit 1
