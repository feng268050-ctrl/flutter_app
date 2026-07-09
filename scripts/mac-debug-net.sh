#!/usr/bin/env bash
# Configure Mac ethernet after board has an IP (e.g. Wi‑Fi or §7.7 ssh enabled).
# Not used at boot — single prod image has no kernel cmdline static eth0 IP.
set -euo pipefail

ADDR="${LWS_HMI_MAC_DEBUG_IP:-10.0.0.1}"
MASK="${LWS_HMI_MAC_DEBUG_MASK:-24}"

if [[ "$(uname -s)" != Darwin ]]; then
  echo "mac-debug-net: macOS only" >&2
  exit 1
fi

echo "Looking for link-up ethernet (board at 10.0.0.240) ..."
found=""
while IFS= read -r ifc; do
  [[ -n "$ifc" ]] || continue
  if networksetup -getinfo "$ifc" 2>/dev/null | grep -q "Ethernet"; then
    if ifconfig "$ifc" 2>/dev/null | grep -q "status: active"; then
      found="$ifc"
      break
    fi
    # Also try interfaces with carrier but inactive IP.
    if ifconfig "$ifc" 2>/dev/null | grep -q "inet "; then
      found="$ifc"
      break
    fi
  fi
done < <(networksetup -listallhardwareports | awk '/Device:/{print $2}')

if [[ -z "$found" ]]; then
  echo "No active Ethernet found. Plug board RJ45 → Mac adapter, wait for link LED." >&2
  echo "Then re-run: bash scripts/mac-debug-net.sh" >&2
  exit 1
fi

echo "Using $found"
sudo ifconfig "$found" "$ADDR/$MASK" up
echo "Mac $found = $ADDR/$MASK — try: ping 10.0.0.240 && ssh root@10.0.0.240"
