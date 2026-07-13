#!/bin/sh
# USB plug-ssh diagnostics for the g_ether implementation.
set -u

pass() { echo "  [PASS] $*"; }
fail() { echo "  [FAIL] $*"; }
info() { echo "  [INFO] $*"; }

echo "=== 1. DWC3 gadget controller ==="
if [ -e /sys/bus/platform/drivers/dwc3/fcc00000.usb ]; then
	pass "fcc00000.usb bound to dwc3"
else
	fail "fcc00000.usb missing"
fi
if [ -e /sys/bus/platform/drivers/dwc3/fd000000.usb ]; then
	fail "fd000000.usb host controller present on the gadget path"
else
	pass "no conflicting fd000000.usb"
fi
state="$(cat /sys/class/udc/fcc00000.usb/state 2>/dev/null || echo missing)"
info "UDC state=$state"

echo ""
echo "=== 2. OTG VBUS ==="
found=0
for state_file in /sys/class/extcon/extcon*/state; do
	[ -r "$state_file" ] || continue
	dev="$(readlink -f "$(dirname "$state_file")" 2>/dev/null || echo ?)"
	case "$dev" in
	*fe8a0000* | *usb2phy0*)
		found=1
		info "$state_file: $(tr '\n' ' ' <"$state_file")"
		if grep -qE '(^|[[:space:]])USB=1([[:space:]]|$)' "$state_file"; then
			pass "OTG VBUS detected"
		else
			info "OTG VBUS absent"
		fi
		;;
	esac
done
[ "$found" -eq 1 ] || fail "OTG extcon node missing"

echo ""
echo "=== 3. g_ether ==="
if [ -d /sys/module/g_ether ]; then
	pass "g_ether module loaded"
	for p in host_addr dev_addr iSerialNumber idVendor idProduct; do
		[ -r "/sys/module/g_ether/parameters/$p" ] || continue
		info "$p=$(cat "/sys/module/g_ether/parameters/$p")"
	done
else
	info "g_ether not loaded (normal with cable unplugged)"
fi
if [ -d /sys/kernel/config/usb_gadget/lws_hmi ]; then
	fail "retired configfs gadget lws_hmi is still present"
else
	pass "no competing lws_hmi configfs gadget"
fi

echo ""
echo "=== 4. usb0 + sshd ==="
if ip -br link show usb0 >/dev/null 2>&1; then
	pass "usb0 link: $(ip -br link show usb0)"
	if ip -br addr show usb0 2>/dev/null | grep -q '192.168.55.1/'; then
		pass "usb0 address: $(ip -br addr show usb0 | awk '{print $3}')"
	else
		fail "usb0 missing 192.168.55.1/24"
	fi
else
	info "usb0 missing"
fi
if ss -lnt 2>/dev/null | grep -q '192.168.55.1:22'; then
	pass "sshd listening on 192.168.55.1:22"
else
	info "sshd not listening on usb0"
fi
if systemctl is-active --quiet lws-hmi-usb-plug-ssh.service 2>/dev/null; then
	pass "lws-hmi-usb-plug-ssh.service active"
else
	info "lws-hmi-usb-plug-ssh.service inactive"
fi

echo ""
echo "=== done ==="
