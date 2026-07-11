#!/bin/sh
# USB plug-ssh diagnostics — run on device; each section prints PASS/FAIL hints.
set -u

pass() { echo "  [PASS] $*"; }
fail() { echo "  [FAIL] $*"; }
info() { echo "  [INFO] $*"; }

echo "=== 1. dwc3 drivers (expect: fcc00000.usb only, NO fd000000.usb) ==="
if [ -d /sys/bus/platform/drivers/dwc3 ]; then
	ls /sys/bus/platform/drivers/dwc3/
	if [ -e /sys/bus/platform/drivers/dwc3/fd000000.usb ]; then
		fail "fd000000.usb present — host blocks gadget (need kernel DTS fix)"
	else
		pass "no fd000000.usb"
	fi
	if [ -e /sys/bus/platform/drivers/dwc3/fcc00000.usb ]; then
		pass "fcc00000.usb present"
	else
		fail "fcc00000.usb missing — gadget controller not bound"
	fi
else
	fail "no /sys/bus/platform/drivers/dwc3"
fi

echo ""
echo "=== 2. UDC (expect: state not-attached or default before bind; configured after Mac enumerates) ==="
if [ -e /sys/class/udc/fcc00000.usb/state ]; then
	st="$(cat /sys/class/udc/fcc00000.usb/state)"
	info "state=$st"
else
	fail "no /sys/class/udc/fcc00000.usb"
fi

echo ""
echo "=== 3. extcon (OTG port fe8a0000 — expect USB=1 when cable plugged into Mac) ==="
found_otg=0
for s in /sys/class/extcon/extcon*/state; do
	[ -r "$s" ] || continue
	dev="$(readlink -f "$(dirname "$s")" 2>/dev/null || echo ?)"
	echo "  $s"
	echo "    dev=$dev"
	echo "    state=$(tr '\n' ' ' <"$s")"
	case "$dev" in
	*fe8a0000* | *usb2phy0*)
		found_otg=1
		if grep -qE '(^|[[:space:]])USB=1([[:space:]]|$)' "$s" 2>/dev/null; then
			pass "OTG VBUS detected (USB=1)"
		else
			fail "OTG VBUS not detected — plug USB cable to Mac"
		fi
		;;
	esac
done
[ "$found_otg" -eq 1 ] || fail "no fe8a0000 / usb2phy0 extcon node found"

echo ""
echo "=== 4. usb_role (expect: device for fcc00000 / fe8a0000; host here causes EBUSY on bind) ==="
for r in /sys/class/usb_role/*/role; do
	[ -r "$r" ] || continue
	dev="$(readlink -f "$(dirname "$(dirname "$r")")" 2>/dev/null || echo ?)"
	role="$(cat "$r" 2>/dev/null || echo ?)"
	echo "  $r"
	echo "    dev=$dev role=$role"
	case "$dev" in
	*fcc00000* | *usbdrd* | *fe8a0000*)
		case "$role" in
		device) pass "role=device (OK for gadget)" ;;
		host) fail "role=host — run: echo device > $r" ;;
		*) info "role=$role (try: echo device > $r)" ;;
		esac
		;;
	esac
done

echo ""
echo "=== 5. otg_mode (expect: peripheral) ==="
if [ -r /sys/devices/platform/fe8a0000.usb2-phy/otg_mode ]; then
	m="$(cat /sys/devices/platform/fe8a0000.usb2-phy/otg_mode)"
	info "otg_mode=$m"
	case "$m" in
	peripheral) pass "otg_mode=peripheral" ;;
	host) fail "otg_mode=host — run: echo peripheral > /sys/devices/platform/fe8a0000.usb2-phy/otg_mode" ;;
	*) info "try: echo peripheral > /sys/devices/platform/fe8a0000.usb2-phy/otg_mode" ;;
	esac
else
	fail "missing /sys/devices/platform/fe8a0000.usb2-phy/otg_mode"
fi

echo ""
echo "=== 6. configfs gadget (lws_hmi — Mac make devices expects 0x2207:0x0019) ==="
GADGET=/sys/kernel/config/usb_gadget/lws_hmi
if [ -d "$GADGET" ]; then
	info "lws_hmi present"
	if [ -f "$GADGET/UDC" ]; then
		udc="$(cat "$GADGET/UDC" 2>/dev/null || true)"
		if [ -n "$udc" ]; then
			pass "gadget UDC=$udc (bound)"
		else
			info "gadget UDC empty (not bound yet)"
		fi
	else
		info "no UDC file yet"
	fi
	if [ -f "$GADGET/idVendor" ] && [ -f "$GADGET/idProduct" ]; then
		info "USB id=$(cat "$GADGET/idVendor" 2>/dev/null):$(cat "$GADGET/idProduct" 2>/dev/null)"
	fi
else
	info "no lws_hmi configfs directory"
fi
if [ -e /sys/class/udc/fcc00000.usb/gadget ]; then
	kg="$(cat /sys/class/udc/fcc00000.usb/gadget 2>/dev/null || echo ?)"
	info "kernel UDC gadget=$kg"
else
	info "kernel UDC gadget=(none)"
fi
st="$(cat /sys/class/udc/fcc00000.usb/state 2>/dev/null || echo unknown)"
if [ "$st" = "configured" ] && ip -br link show usb0 >/dev/null 2>&1; then
	if [ -d "$GADGET" ] && [ "$(cat "$GADGET/UDC" 2>/dev/null || true)" = "fcc00000.usb" ]; then
		pass "ECM enumerated (configured + lws_hmi bound)"
	elif [ ! -d "$GADGET" ]; then
		pass "ECM enumerated (configured + usb0) — orphan session; run usb-plug-ssh-start.sh"
	else
		info "configured + usb0 but lws_hmi not bound — run usb-plug-ssh-start.sh"
	fi
fi

echo ""
echo "=== 7. usb0 address + sshd (board side must be 192.168.55.1) ==="
if ip -br link show usb0 >/dev/null 2>&1; then
	pass "usb0 link: $(ip -br link show usb0)"
	if ip -br addr show usb0 2>/dev/null | grep -q '192.168.55.1/'; then
		pass "usb0 addr: $(ip -br addr show usb0 | awk '{print $3}')"
	else
		fail "usb0 missing 192.168.55.1/24 — run: /usr/lib/lws-hmi/usb-plug-ssh-start.sh"
	fi
else
	info "usb0 missing (normal until ECM bound + enumerated)"
fi
if ls /etc/ssh/ssh_host_*_key >/dev/null 2>&1; then
	pass "ssh host keys present"
else
	fail "no /etc/ssh/ssh_host_*_key — run ensure-sshd-hostkeys.sh"
fi
if ss -lntp 2>/dev/null | grep -q '192.168.55.1:22'; then
	pass "sshd listening on 192.168.55.1:22"
elif ss -lnt 2>/dev/null | grep -q '192.168.55.1:22'; then
	pass "sshd listening on 192.168.55.1:22"
else
	fail "sshd not on 192.168.55.1:22 — run: /usr/lib/lws-hmi/usb-plug-ssh-start.sh"
fi
if systemctl is-active --quiet lws-hmi-usb-plug-ssh.service 2>/dev/null; then
	pass "lws-hmi-usb-plug-ssh.service active"
else
	info "lws-hmi-usb-plug-ssh.service not active — run: systemctl start lws-hmi-usb-plug-ssh.service"
fi

echo ""
echo "=== 8. kernel device-tree hint (u2phy0_host should be disabled in flashed kernel) ==="
if [ -r /sys/firmware/devicetree/base/usb2-phy@fe8a0000/host-port/status ]; then
	hst="$(tr -d '\000' </sys/firmware/devicetree/base/usb2-phy@fe8a0000/host-port/status 2>/dev/null || true)"
	info "DT host-port status=$hst"
	[ "$hst" = "disabled" ] && pass "DT host-port disabled" || fail "DT host-port NOT disabled — need: make build-kernel && flash"
else
	info "cannot read DT host-port status (may still need kernel rebuild)"
fi

echo ""
echo "=== done ==="
echo "  Board ready when: usb0 has 192.168.55.1/24 AND sshd on 192.168.55.1:22"
echo "  Then on Mac: sudo ifconfig <enX> 192.168.55.2/24 up  →  ping 192.168.55.1  →  make devices"
echo "  If start fails or Mac USB empty after start: unplug/replug USB, then usb-plug-ssh-start.sh again"
