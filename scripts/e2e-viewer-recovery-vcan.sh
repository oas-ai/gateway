#!/usr/bin/env bash
set -euo pipefail

runtime_bin=${1:?usage: e2e-viewer-recovery-vcan.sh <ohayess-runtime> <ohayess-viewer> [gateway-host] [supervisor]}
viewer_bin=${2:?usage: e2e-viewer-recovery-vcan.sh <ohayess-runtime> <ohayess-viewer> [gateway-host] [supervisor]}
gateway_bin=${3:-target/debug/oas-gateway-host}
supervisor=${4:-./scripts/run-gateway-runtime.sh}
browser_bin=${OAS_VIEWER_BROWSER:-google-chrome}
source "$(dirname "$0")/fixtures/palisade-2020-diagnostics.sh"
temp_dir=$(mktemp -d)
supervisor_log="$temp_dir/supervisor.log"
gateway_pid_file="$temp_dir/gateway.pid"
viewer_address="127.0.0.1:18080"
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
OAS_VIEWER_BIN="$viewer_bin" \
OAS_VIEWER_ADDRESS="$viewer_address" \
"$supervisor" "$runtime_bin" "$gateway_bin" vcan0 0 2>"$supervisor_log" &
supervisor_pid=$!

for _ in {1..50}; do
  curl --fail --silent --max-time 1 "http://$viewer_address/state" >/dev/null 2>&1 && break
  sleep 0.1
done
curl --fail --silent --max-time 1 "http://$viewer_address/" | grep -q 'OAS VehicleState Viewer'

for _ in {1..20}; do
  [[ -s $gateway_pid_file ]] && break
  sleep 0.1
done
old_gateway_pid=$(<"$gateway_pid_file")
kill -0 "$old_gateway_pid"

send_frames() {
  send_palisade_2020_frames
}

send_frames_continuously() {
  while true; do
    send_frames
    sleep 0.1
  done
}

wait_for_speed() {
  for _ in {1..30}; do
    curl --fail --silent --max-time 1 "http://$viewer_address/state" | grep -Eq '"speedMps":22\.222' && return 0
    sleep 0.1
  done
  cat "$supervisor_log" >&2
  return 1
}

render_viewer() {
  local route=$1
  local profile=${route//\//-}
  "$browser_bin" \
    --headless=new \
    --no-sandbox \
    --disable-gpu \
    --disable-dev-shm-usage \
    --user-data-dir="$temp_dir/chrome-$profile" \
    --virtual-time-budget=1000 \
    --dump-dom "http://$viewer_address/#$route" > "$temp_dir/viewer-$profile.html"
}

assert_viewer() {
  local route=$1
  local pattern=$2
  local profile=${route//\//-}
  render_viewer "$route"
  if ! grep -Eq "$pattern" "$temp_dir/viewer-$profile.html"; then
    echo "Viewer assertion failed for #$route: $pattern" >&2
    cat "$temp_dir/viewer-$profile.html" >&2
    return 1
  fi
}

send_frames
wait_for_speed
send_frames_continuously &
frame_sender_pid=$!
assert_viewer media '재생 조건: vehicle_in_motion'
assert_viewer media 'data-theme="dark"'

for route in home media workspace vehicle settings diagnostics; do
  assert_viewer "$route" "<section class=\"screen\" data-screen=\"$route\">"
done
assert_viewer home '오늘의 주행'
assert_viewer home 'Vehicle state'
assert_viewer media/library 'data-tab-panel="library" class="content-grid">'
assert_viewer media/library 'data-tab-panel="player" class="dashboard-grid" hidden(="")?>'
assert_viewer vehicle/vision 'data-tab-panel="vision" class="dashboard-grid">'
assert_viewer settings/safety 'data-tab-panel="safety" class="settings-list">'
assert_viewer settings/display 'data-theme-choice="auto"'
assert_viewer workspace 'class="split-workspace"'
assert_viewer diagnostics/logs 'data-tab-panel="logs" class="settings-list">'

kill -TERM "$old_gateway_pid"
for _ in {1..40}; do
  new_gateway_pid=$(<"$gateway_pid_file")
  [[ $new_gateway_pid != "$old_gateway_pid" ]] && kill -0 "$new_gateway_pid" 2>/dev/null && break
  sleep 0.1
done
[[ $new_gateway_pid != "$old_gateway_pid" ]]

send_frames
wait_for_speed
assert_viewer diagnostics/can 'data-tab-panel="can" class="content-grid">'
assert_viewer diagnostics/can '제어·안전 판단에는 사용하지 않습니다'
assert_viewer diagnostics/can 'door sw 1.*belt D/P 1/1.*door D/P/RL/RR 1/2/3/0.*temp D/P 20/22°C'
