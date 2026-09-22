#!/usr/bin/env bash
set -euo pipefail

runtime_bin=${1:?usage: e2e-hmi-recovery-vcan.sh <ohayess-runtime> <ohayess-hmi> [gateway-host] [supervisor]}
hmi_bin=${2:?usage: e2e-hmi-recovery-vcan.sh <ohayess-runtime> <ohayess-hmi> [gateway-host] [supervisor]}
gateway_bin=${3:-target/debug/oas-gateway-host}
supervisor=${4:-./scripts/run-gateway-runtime.sh}
browser_bin=${OAS_HMI_BROWSER:-google-chrome}
temp_dir=$(mktemp -d)
supervisor_log="$temp_dir/supervisor.log"
gateway_pid_file="$temp_dir/gateway.pid"
hmi_address="127.0.0.1:18080"
supervisor_pid=""
frame_sender_pid=""

cleanup() {
  [[ -n $frame_sender_pid ]] && kill "$frame_sender_pid" 2>/dev/null || true
  [[ -n $frame_sender_pid ]] && wait "$frame_sender_pid" 2>/dev/null || true
  [[ -n $supervisor_pid ]] && kill "$supervisor_pid" 2>/dev/null || true
  [[ -n $supervisor_pid ]] && wait "$supervisor_pid" 2>/dev/null || true
  rm -rf "$temp_dir"
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
  cansend vcan0 541#0000008000000000
}

send_frames_continuously() {
  while true; do
    send_frames
    sleep 0.1
  done
}

wait_for_speed() {
  for _ in {1..30}; do
    curl --fail --silent --max-time 1 "http://$hmi_address/state" | grep -Eq '"speedMps":22\.222' && return 0
    sleep 0.1
  done
  cat "$supervisor_log" >&2
  return 1
}

render_hmi() {
  local route=$1
  local profile=${route//\//-}
  "$browser_bin" \
    --headless=new \
    --no-sandbox \
    --disable-gpu \
    --disable-dev-shm-usage \
    --user-data-dir="$temp_dir/chrome-$profile" \
    --virtual-time-budget=1000 \
    --dump-dom "http://$hmi_address/#$route" > "$temp_dir/hmi-$profile.html"
}

assert_hmi() {
  local route=$1
  local pattern=$2
  local profile=${route//\//-}
  render_hmi "$route"
  if ! grep -Eq "$pattern" "$temp_dir/hmi-$profile.html"; then
    echo "HMI assertion failed for #$route: $pattern" >&2
    cat "$temp_dir/hmi-$profile.html" >&2
    return 1
  fi
}

send_frames
wait_for_speed
send_frames_continuously &
frame_sender_pid=$!
assert_hmi media '재생 조건: vehicle_in_motion'
assert_hmi media 'data-theme="dark"'

for route in home media workspace vehicle settings diagnostics; do
  assert_hmi "$route" "<section class=\"screen\" data-screen=\"$route\">"
done
assert_hmi media/library 'data-tab-panel="library" class="content-grid">'
assert_hmi media/library 'data-tab-panel="player" class="dashboard-grid" hidden(="")?>'
assert_hmi vehicle/vision 'data-tab-panel="vision" class="dashboard-grid">'
assert_hmi settings/safety 'data-tab-panel="safety" class="settings-list">'
assert_hmi settings/display 'data-theme-choice="auto"'
assert_hmi workspace 'class="split-workspace"'
assert_hmi diagnostics/logs 'data-tab-panel="logs" class="settings-list">'

kill -TERM "$old_gateway_pid"
for _ in {1..40}; do
  new_gateway_pid=$(<"$gateway_pid_file")
  [[ $new_gateway_pid != "$old_gateway_pid" ]] && kill -0 "$new_gateway_pid" 2>/dev/null && break
  sleep 0.1
done
[[ $new_gateway_pid != "$old_gateway_pid" ]]

send_frames
wait_for_speed
assert_hmi diagnostics/can 'data-tab-panel="can" class="content-grid">'
