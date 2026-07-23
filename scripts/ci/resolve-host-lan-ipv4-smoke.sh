#!/usr/bin/env bash
# Smoke: print resolve_host_lan_ipv4() result (empty exit 0 when undetectable).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../emulator-system-common.sh
source "${ROOT_DIR}/scripts/emulator-system-common.sh"

ip="$(resolve_host_lan_ipv4 || true)"
if [[ -n "${ip}" ]]; then
  echo "resolve_host_lan_ipv4: ${ip}"
else
  echo "resolve_host_lan_ipv4: (empty — set HOST_IP in .env to override)"
fi
