#!/bin/sh
# USB plug-ssh diagnostics (manual USB Debug preference).
set -u

pass() { echo "  [PASS] $*"; }
fail() { echo "  [FAIL] $*"; }
info() { echo "  [INFO] $*"; }

echo "=== 1. USB Debug preference ==="
if [ -x /usr/lib/lws-hmi/usb-otg-mode.sh ]; then
	info "$(/usr/lib/lws-hmi/usb-otg-mode.sh status 2>&1 || true)"
else
	fail "usb-otg-mode.sh missing"
fi
if [ -r /var/lib/lws-hmi/usb-debug ]; then
	info "pref file: $(tr -d '\n' </var/lib/lws-hmi/usb-debug)"
else
	info "pref file missing (default USB Debug ON)"
fi

echo ""
echo "=== 2. DWC3 / otg_mode ==="
if [ -e /sys/bus/platform/drivers/dwc3/fcc00000.usb ]; then
	pass "fcc00000.usb (usbdrd / Micro-USB) bound"
else
	fail "fcc00000.usb missing"
fi
if [ -r /sys/firmware/devicetree/base/usbdrd/usb@fcc00000/dr_mode ]; then
	info "DT dr_mode=$(tr -d '\0' </sys/firmware/devicetree/base/usbdrd/usb@fcc00000/dr_mode)"
fi
if [ -r /sys/devices/platform/fe8a0000.usb2-phy/otg_mode ]; then
	info "phy otg_mode=$(cat /sys/devices/platform/fe8a0000.usb2-phy/otg_mode)"
fi
state="$(cat /sys/class/udc/fcc00000.usb/state 2>/dev/null || echo none)"
info "UDC state=$state"

echo ""
echo "=== 3. OTG extcon (fe8a0000) ==="
found=0
for state_file in /sys/class/extcon/extcon*/state; do
	[ -r "$state_file" ] || continue
	dev="$(readlink -f "$(dirname "$state_file")" 2>/dev/null || echo ?)"
	case "$dev" in
	*fe8a0000* | *usb2phy0*)
		found=1
		info "$state_file: $(tr '\n' ' ' <"$state_file")"
		;;
	esac
done
[ "$found" -eq 1 ] || fail "OTG extcon missing"

echo ""
echo "=== 4. g_ether / usb0 ==="
if [ -d /sys/module/g_ether ]; then
	pass "g_ether loaded"
else
	info "g_ether not loaded"
fi
if ip -br link show usb0 >/dev/null 2>&1; then
	pass "usb0: $(ip -br addr show usb0 | awk '{print $1,$2,$3}')"
else
	info "usb0 missing"
fi
if systemctl is-active --quiet lws-hmi-usb-plug-ssh.service 2>/dev/null; then
	pass "lws-hmi-usb-plug-ssh.service active"
else
	info "lws-hmi-usb-plug-ssh.service inactive"
fi

echo ""
echo "=== done ==="
