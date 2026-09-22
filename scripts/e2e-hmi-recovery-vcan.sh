#!/usr/bin/env bash
set -euo pipefail

runtime_bin=${1:?usage: e2e-hmi-recovery-vcan.sh <ohayess-runtime> <ohayess-hmi> [gateway-host] [supervisor]}
hmi_bin=${2:?usage: e2e-hmi-recovery-vcan.sh <ohayess-runtime> <ohayess-hmi> [gateway-host] [supervisor]}
gateway_bin=${3:-target/debug/oas-gateway-host}
supervisor=${4:-./scripts/run-gateway-runtime.sh}
temp_dir=$(mktemp -d)
supervisor_log="$temp_dir/supervisor.log"
gateway_pid_file="$temp_dir/gateway.pid"
hmi_address="127.0.0.1:18080"
supervisor_pid=""

cleanup() {
  [[ -n $supervisor_pid ]] && kill "$supervisor_pid" 2>/dev/null || true
  [[ -n $supervisor_pid ]] && wait "$supervisor_pid" 2>/dev/null || true
  rm -f "$supervisor_log" "$gateway_pid_file"
  rmdir "$temp_dir"
}
trap cleanup EXIT

OAS_GATEWAY_PID_FILE="$gateway_pid_file" \
OAS_HMI_BIN="$hmi_bin" \
OAS_HMI_ADDRESS="$hmi_address" \
"$supervisor" "$runtime_bin" "$gateway_bin" vcan0 0 2>"$supervisor_log" &
supervisor_pid=$!

for _ in {1..50}; do
  curl --fail --silent --max-time 1 "http://$hmi_address/state" >/dev/null 2>&1 && break
  sleep 0.1
done
curl --fail --silent --max-time 1 "http://$hmi_address/" | grep -q 'OAS HMI'

for _ in {1..20}; do
  [[ -s $gateway_pid_file ]] && break
  sleep 0.1
done
old_gateway_pid=$(<"$gateway_pid_file")
kill -0 "$old_gateway_pid"

send_frames() {
  cansend vcan0 4F1#00A00000
  cansend vcan0 2B0#8403000000
  cansend vcan0 394#000000007C440000
}

wait_for_speed() {
  for _ in {1..30}; do
    curl --fail --silent --max-time 1 "http://$hmi_address/state" | grep -Eq '"speedMps":22\.222' && return 0
    sleep 0.1
  done
  cat "$supervisor_log" >&2
  return 1
}

send_frames
wait_for_speed

kill -TERM "$old_gateway_pid"
for _ in {1..40}; do
  new_gateway_pid=$(<"$gateway_pid_file")
  [[ $new_gateway_pid != "$old_gateway_pid" ]] && kill -0 "$new_gateway_pid" 2>/dev/null && break
  sleep 0.1
done
[[ $new_gateway_pid != "$old_gateway_pid" ]]

send_frames
wait_for_speed
