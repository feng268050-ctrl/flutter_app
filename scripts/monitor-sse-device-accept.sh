#!/usr/bin/env bash
# Device acceptance for LAN Monitor SSE (HAL event-driven).
# Unit tests do NOT cover RTU contention or UI interference — run on board.
#
# Prereq: HMI running with :5580; board reachable (make devices / SN=...).
#
# Usage:
#   BOARD_IP=192.168.x.x bash scripts/monitor-sse-device-accept.sh
#   # or SN=… then resolve IP via make / ssh helpers yourself
#
# Checklist (manual + curl):
# 1) curl -N --max-time 20 "http://$BOARD_IP:5580/v1/monitor/stat"
#    → first event: stat; within ~15s: heartbeat {"ok":true}
#    → deviceStatus/deviceData keys present; processParameters may be null
# 2) Open Monitor on device while (1) runs → trigger gun/air/estop change
#    → another event: stat with updated fields (not heartbeat-only)
# 3) curl -N "http://$BOARD_IP:5580/v1/monitor/alerts"
#    → list array length ≤10; raise alarm → event: new with id;
#      clear history → event: clear + {}
# 4) Two curl -N on /stat → both see the same change fan-out
# 5) With Monitor + Quick apply + dual SSE: stream stays alive; no extra
#    readGroup storm (HMI UI still updates)
set -euo pipefail

BOARD_IP="${BOARD_IP:-}"
if [[ -z "${BOARD_IP}" ]]; then
  echo "Set BOARD_IP to the device LAN address." >&2
  exit 2
fi

BASE="http://${BOARD_IP}:5580"
echo "== GET ${BASE}/lasercyber =="
curl -fsS "${BASE}/lasercyber"
echo

echo "== SSE /v1/monitor/stat (20s) =="
curl -N --max-time 20 "${BASE}/v1/monitor/stat" || true
echo

echo "== SSE /v1/monitor/alerts (12s) =="
curl -N --max-time 12 "${BASE}/v1/monitor/alerts" || true
echo

echo "Done. Complete manual interference steps in the header comments."
