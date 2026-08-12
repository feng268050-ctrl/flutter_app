#!/usr/bin/env bash
# Smoke: provision mount/bind, identity, cloud Ed25519 storage path, HMI cloud logs.
# Usage: SN=<device> bash scripts/smoke-provision.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"

SMOKE='
echo "=== SMOKE $(read-identity sn 2>/dev/null || echo unknown) ==="
echo "--- provision ---"
mount | grep -F provision || echo "provision: not mounted"
ls -la /mnt/provision/ 2>/dev/null || true
echo "--- identity ---"
read-identity 2>/dev/null || true
echo "--- properties bind ---"
readlink /var/lib/hal/properties.ini 2>/dev/null || ls -la /var/lib/hal/properties.ini 2>/dev/null || true
echo "--- vendor_storage ---"
[ -e /dev/vendor_storage ] && echo VS=present || echo VS=absent
echo "--- cloud ed25519 ---"
if /usr/bin/read-cloud-ed25519-sealed --present 2>/dev/null; then
  echo sealed=present
else
  echo sealed=absent
fi
if [ -f /mnt/provision/cloud-ed25519.sealed ]; then
  echo "provision_blob=$(wc -c </mnt/provision/cloud-ed25519.sealed) bytes"
else
  echo provision_blob=none
fi
if [ -e /dev/vendor_storage ] && [ -x /usr/bin/vendor_storage ]; then
  tmp=$(mktemp)
  if /usr/bin/vendor_storage -r VENDOR_CUSTOM_ID_16 -t file -i "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
    echo "vs_id22=$(wc -c <"$tmp") bytes"
  else
    echo vs_id22=empty
  fi
  rm -f "$tmp"
fi
echo "--- api ---"
curl -sS -o /dev/null -w "api=%{http_code}\n" --connect-timeout 8 https://api-prod.lasercyber.workers.dev/ || echo api=fail
echo "--- hmi cloud ---"
journalctl -u hmi.service --no-pager -n 120 2>/dev/null \
  | grep -E "cloud-ed25519|device-ws|users probe|401|activated|TOKEN|offlineAuth" \
  | tail -15 || true
'

usb_ssh_session_prepare "$ROOT"
if usb_ssh_session_is_remote; then
  echo "target: SSH $TARGET_USER@$TARGET_ADDR (SN=${SN:-auto})"
else
  echo "target: USB-SSH $IFACE $TARGET_USER@$TARGET_ADDR (SN=${SN:-auto})"
fi
usb_ssh_session_run_ssh "$ROOT" "$IFACE" bash -s <<<"$SMOKE"
