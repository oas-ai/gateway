#!/usr/bin/env bash
set -euo pipefail

interface=${1:-can0}
service=${2:-"oas-gateway-runtime@$interface.service"}
viewer_address=${OAS_VIEWER_ADDRESS:-127.0.0.1:8080}
expected_bitrate=${OAS_CAN_BITRATE:-}

fail() {
  echo "preflight: $*" >&2
  exit 1
}

[[ ${OSTYPE:-} == linux* ]] || fail "Linux SocketCAN is required"
for command in ip systemctl curl; do
  command -v "$command" >/dev/null || fail "missing command: $command"
done

link=$(ip -details link show dev "$interface") || fail "missing interface: $interface"
grep -Eq '<[^>]*UP[^>]*>' <<<"$link" || fail "$interface is not UP"
grep -q 'can ' <<<"$link" || fail "$interface is not a CAN interface"
if [[ -n $expected_bitrate ]]; then
  grep -Fq "bitrate $expected_bitrate" <<<"$link" || fail "$interface bitrate is not $expected_bitrate"
else
  grep -Eq 'bitrate [1-9][0-9]*' <<<"$link" || fail "$interface has no configured bitrate"
fi

systemctl is-active --quiet "$service" || fail "$service is not active"
[[ $(systemctl show "$service" -p NoNewPrivileges --value) == yes ]] || fail "$service permits new privileges"

state=$(curl --fail --silent --show-error --max-time 2 "http://$viewer_address/state") || fail "Viewer state endpoint is unavailable"
grep -Fq '"rawDiagnostics"' <<<"$state" || fail "Viewer state lacks raw diagnostics"

echo "preflight: $interface, $service, and Viewer state are read-only ready"
