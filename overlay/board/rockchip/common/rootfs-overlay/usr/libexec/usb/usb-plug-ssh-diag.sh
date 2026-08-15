#!/bin/sh
# USB plug-ssh diagnostics (manual USB Debug preference).
# Board-agnostic: discovers usb2-phy otg_mode + UDC (ynh960 / ek3562 / …).
set -u

# shellcheck source=/dev/null
. /usr/libexec/usb/usb-otg-paths.sh 2>/dev/null || true

pass() { echo "  [PASS] $*"; }
fail() { echo "  [FAIL] $*"; }
info() { echo "  [INFO] $*"; }

echo "=== 1. USB OTG session ==="
if [ -x /usr/libexec/usb/usb-otg-mode.sh ]; then
	info "$(/usr/libexec/usb/usb-otg-mode.sh status 2>&1 || true)"
else
	fail "usb-otg-mode.sh missing"
fi
if [ -r /var/lib/hal/usb-otg.conf ]; then
	info "otg conf: $(tr -d '\n' </var/lib/hal/usb-otg.conf)"
else
	info "otg conf: missing (default mode=debug)"
fi
if [ -r /etc/usb-otg.ini ]; then
	info "otg ini: $(tr '\n' ' ' </etc/usb-otg.ini | tr -s ' ')"
fi

echo ""
echo "=== 2. DWC3 / otg_mode / UDC ==="
phy=""
if [ "${USB_OTG_PATHS_LOADED:-}" = 1 ]; then
	phy="$(usb_otg_phy_mode_path 2>/dev/null || true)"
fi
if [ -n "$phy" ] && [ -r "$phy" ]; then
	pass "phy otg_mode path=$phy val=$(tr -d ' \n' <"$phy")"
elif [ -n "$phy" ]; then
	info "phy otg_mode path=$phy (not readable yet)"
else
	fail "otg_mode sysfs not found"
fi

udc_found=0
for udc in /sys/class/udc/*; do
	[ -e "$udc" ] || continue
	udc_found=1
	name="$(basename "$udc")"
	state="$(tr -d ' \n' <"$udc/state" 2>/dev/null || echo none)"
	pass "UDC $name state=$state"
	# Bound dwc3 platform device (symlink under drivers/dwc3).
	if [ -e "/sys/bus/platform/drivers/dwc3/$name" ]; then
		pass "dwc3 driver bound: $name"
	else
		info "dwc3 driver node missing for $name (may still be OK)"
	fi
done
[ "$udc_found" -eq 1 ] || fail "no /sys/class/udc/*"

# Best-effort DT dr_mode for known Rockchip usbdrd layouts.
for dt in /sys/firmware/devicetree/base/usbdrd/usb@*/dr_mode \
	/sys/firmware/devicetree/base/usbdrd*/usb@*/dr_mode; do
	[ -r "$dt" ] || continue
	info "DT $(basename "$(dirname "$dt")") dr_mode=$(tr -d '\0' <"$dt")"
done

echo ""
echo "=== 3. OTG extcon (usb2-phy) ==="
found=0
if [ "${USB_OTG_PATHS_LOADED:-}" = 1 ]; then
	if state="$(usb_otg_read_extcon_state 2>/dev/null)"; then
		found=1
		info "extcon: $(printf '%s' "$state" | tr '\n' ' ')"
	fi
fi
if [ "$found" -eq 0 ]; then
	for state_file in /sys/class/extcon/extcon*/state; do
		[ -r "$state_file" ] || continue
		dev="$(readlink -f "$(dirname "$state_file")" 2>/dev/null || echo ?)"
		case "$dev" in
		*.usb2-phy | *.usb2-phy/* | *usb2phy* | *fe8a0000* | *ff740000*)
			found=1
			info "$state_file: $(tr '\n' ' ' <"$state_file")"
			;;
		esac
	done
fi
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
if systemctl is-active --quiet ssh-debug-usb.service 2>/dev/null; then
	pass "ssh-debug-usb.service active"
else
	info "ssh-debug-usb.service inactive"
fi

echo ""
echo "=== done ==="
