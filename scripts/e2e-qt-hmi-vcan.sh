#!/usr/bin/env bash
set -euo pipefail
runtime_bin=${1:?runtime binary required}
hmi_bin=${2:?Qt HMI binary required}
gateway_bin=${3:-target/debug/oas-gateway-host}
source "$(dirname "$0")/fixtures/palisade-2020-diagnostics.sh"
test_dir=$(mktemp -d)
supervisor_pid=""
hmi_pid=""
cleanup() {
  for pid in "$hmi_pid" "$supervisor_pid"; do
    [[ -n $pid ]] && kill "$pid" 2>/dev/null || true
  done
  for pid in "$hmi_pid" "$supervisor_pid"; do
    [[ -n $pid ]] && wait "$pid" 2>/dev/null || true
  done
  rm -f "$test_dir/state" "$test_dir/hmi.log"
  rmdir "$test_dir"
}
trap cleanup EXIT
mkfifo "$test_dir/state"
mkdir -p target/hmi-artifacts
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software "$hmi_bin" \
  --stream "$test_dir/state" --expect-speed 80 --size 1280x720 \
  --capture "$PWD/target/hmi-artifacts/vcan-qt.png" >"$test_dir/hmi.log" 2>&1 &
hmi_pid=$!
OAS_HMI_STREAM="$test_dir/state" ./scripts/run-gateway-runtime.sh "$runtime_bin" "$gateway_bin" vcan0 0 &
supervisor_pid=$!
for _ in {1..50}; do
  kill -0 "$hmi_pid" 2>/dev/null || break
  send_palisade_2020_frames
  sleep 0.1
done
if ! wait "$hmi_pid"; then
  cat "$test_dir/hmi.log"
  exit 1
fi
if grep -Eq 'ReferenceError|TypeError|Unable to assign|failed to load' "$test_dir/hmi.log"; then
  cat "$test_dir/hmi.log"
  exit 1
fi
test -s target/hmi-artifacts/vcan-qt.png
