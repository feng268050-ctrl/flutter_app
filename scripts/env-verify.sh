#!/bin/sh
# §3.4 platform stack verification on ynh960 device (excludes flutter-pi / hmi boot KPI).
# Run after flash: verify-env
# Canonical copy: overlay/.../rootfs-overlay/usr/libexec/hmi/env-verify.sh
set -u

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*"; FAILED=1; }
warn() { echo "WARN: $*"; }
prep_ok() { echo "PASS: $* (P1 prep-only — absent on rootfs is OK)"; }

FAILED=0

echo "=== verify-env (§3.4 platform stack, no flutter-pi) ==="

echo ""
echo "--- RKNPU2 runtime (P1 rootfs) ---"
if [ -f /usr/lib/librknnrt.so ]; then
	pass "librknnrt.so present"
else
	fail "librknnrt.so missing (host: make fetch-rknn-rt && make build-rootfs)"
fi
if [ -x /usr/bin/rknn_server ]; then
	pass "rknn_server present"
else
	fail "rknn_server missing"
fi
if command -v ldconfig >/dev/null 2>&1; then
	if ldconfig -p 2>/dev/null | grep -q librknnrt; then
		pass "librknnrt in ldconfig cache"
	else
		warn "librknnrt not listed by ldconfig -p (may still load via path)"
	fi
fi
if command -v rknn_common_test >/dev/null 2>&1 || [ -x /usr/bin/rknn_common_test ]; then
	fail "rknn_common_test present (demo binary should be absent)"
else
	pass "rknn_common_test absent"
fi
if pidof rknn_server >/dev/null 2>&1; then
	warn "rknn_server running (optional until P3; not required @ P1 boot)"
else
	pass "rknn_server not running"
fi
echo ""
echo "--- Flutter HMI (/opt/hmi app + system engine) ---"
if [ -f /opt/hmi/lib/libapp.so ]; then
	pass "libapp.so present"
else
	fail "/opt/hmi/lib/libapp.so missing"
fi
if [ -f /opt/hmi/data/flutter_assets/AssetManifest.bin ]; then
	pass "flutter_assets present"
else
	fail "/opt/hmi/data/flutter_assets missing"
fi
if [ -f /opt/hmi/lib/libflutter_engine.so ]; then
	fail "/opt/hmi/lib/libflutter_engine.so present (engine must be rootfs /usr/lib only)"
else
	pass "bundle libflutter_engine.so absent (system engine)"
fi
if [ -f /opt/hmi/data/icudtl.dat ]; then
	fail "/opt/hmi/data/icudtl.dat present (use /usr/share/flutter on rootfs)"
else
	pass "bundle icudtl.dat absent (system icu)"
fi
if [ -f /usr/lib/libflutter_engine.so ]; then
	pass "system libflutter_engine.so present"
else
	fail "/usr/lib/libflutter_engine.so missing (rebuild rootfs with flutter-engine prebuilt)"
fi
if [ -f /usr/share/flutter/icudtl.dat ] || [ -f /usr/share/flutter/release/data/icudtl.dat ]; then
	pass "system icudtl.dat present"
else
	fail "system icudtl.dat missing under /usr/share/flutter"
fi
if pidof flutter-pi >/dev/null 2>&1; then
	pass "flutter-pi process running"
else
	warn "flutter-pi not running"
fi

echo ""
echo "--- flutter-pi keyboard runtime (xkb + Compose) ---"
if [ -f /usr/share/X11/xkb/rules/evdev ]; then
	pass "xkeyboard-config rules/evdev present"
else
	fail "/usr/share/X11/xkb/rules/evdev missing (enable BR2_PACKAGE_XKEYBOARD_CONFIG)"
fi
if [ -f /usr/share/X11/locale/C/Compose ] && [ -f /usr/share/X11/locale/compose.dir ]; then
	pass "X11 locale Compose stubs present"
else
	fail "/usr/share/X11/locale Compose stubs missing (fs-overlay usr/share/X11/locale)"
fi
if [ -f /etc/default/keyboard ]; then
	pass "/etc/default/keyboard present"
else
	warn "/etc/default/keyboard missing (flutter-pi uses built-in defaults)"
fi

echo ""
echo "--- RockUSB Loader reboot helper ---"
if [ -x /usr/libexec/hmi/reboot-loader ] && [ -x /usr/bin/reboot-loader ]; then
	pass "reboot-loader installed in PATH (RESTART2 loader — not busybox reboot)"
else
	fail "reboot-loader missing from /usr/libexec/hmi or /usr/bin"
fi

npu_sysfs=0
for p in /sys/class/misc/rknpu /sys/devices/platform/*rknpu*; do
	[ -e "$p" ] || continue
	npu_sysfs=1
	pass "kernel NPU sysfs: $p"
	break
done
if [ "$npu_sysfs" -eq 0 ]; then
	if dmesg 2>/dev/null | grep -qi rknpu; then
		pass "dmesg mentions RKNPU"
	else
		warn "no RKNPU sysfs node — check kernel driver / DTS if inference fails"
	fi
fi

echo ""
echo "--- GPU / display libs (Mali, libdrm — not flutter-pi) ---"
gpu_ok=0
for lib in /usr/lib/libmali.so* /usr/lib/libMali.so* /usr/lib/libdrm.so* /usr/lib/libgbm.so*; do
	[ -e "$lib" ] || continue
	gpu_ok=1
done
if [ "$gpu_ok" -eq 1 ]; then
	pass "Mali/libdrm userland libraries present"
else
	fail "Mali/libdrm libraries missing under /usr/lib"
fi

echo ""
echo "--- wifibt stack (P1 rootfs; boot-deferred) ---"
if command -v wpa_supplicant >/dev/null 2>&1; then
	pass "wpa_supplicant installed"
else
	fail "wpa_supplicant missing"
fi
if command -v wpa_cli >/dev/null 2>&1; then
	pass "wpa_cli installed"
else
	fail "wpa_cli missing"
fi
if command -v dhcpcd >/dev/null 2>&1; then
	pass "dhcpcd installed (wlan0 helper)"
elif command -v udhcpc >/dev/null 2>&1; then
	pass "udhcpc installed (wlan0 helper fallback)"
else
	fail "dhcpcd/udhcpc missing (enable BR2_PACKAGE_DHCPCD)"
fi
if [ -f /etc/ssl/certs/ca-certificates.crt ] || [ -d /etc/ssl/certs ]; then
	# Bundle preferred; hashed pem dir alone is also usable by some stacks.
	if [ -s /etc/ssl/certs/ca-certificates.crt ]; then
		pass "CA bundle /etc/ssl/certs/ca-certificates.crt"
	else
		warn "CA dir present but ca-certificates.crt missing (HTTPS may fail in Dart)"
	fi
else
	fail "CA certificates missing (enable BR2_PACKAGE_CA_CERTIFICATES)"
fi
for helper in wifi-stack-up.sh wifi-stack-down.sh wlan0-dhcp.sh wlan0-static.sh wlan0-time-sync.sh; do
	if [ -x "/usr/libexec/wpa/$helper" ]; then
		pass "helper $helper"
	else
		fail "helper $helper missing or not executable (/usr/libexec/wpa/)"
	fi
done
for helper in eth0-dhcp.sh eth0-static.sh eth0-link.sh apply-eth0.sh; do
	if [ -x "/usr/libexec/network/$helper" ]; then
		pass "helper $helper"
	else
		fail "helper $helper missing or not executable (/usr/libexec/network/)"
	fi
done
for helper in bt-stack-up.sh bt-stack-down.sh bt-pair-agent.sh bt-ensure-agent.sh bt-set-alias.sh bt-trust-paired.sh bt-hid-heal.sh bt-hid-heal-loop.sh wifibt-bringup.sh; do
	if [ -x "/usr/libexec/bluetooth/$helper" ]; then
		pass "helper $helper"
	else
		fail "helper $helper missing or not executable (/usr/libexec/bluetooth/)"
	fi
done
for helper in restore-settings.sh change-backlight.sh change-volume.sh change-orientation.sh apply-mouse-settings.sh bind-prefs.sh; do
	if [ -x "/usr/libexec/hmi/$helper" ]; then
		pass "helper $helper"
	else
		fail "helper $helper missing or not executable (/usr/libexec/hmi/)"
	fi
done
year="$(date -u +%Y 2>/dev/null || echo 0)"
case "$year" in
2025|2026|2027|2028|2029|2030)
	pass "wall clock year=$year"
	;;
*)
	warn "wall clock year=$year (HTTPS certs may fail until wlan0-time-sync after Wi-Fi)"
	;;
esac
# AIC8800D80 modules (kernel + post-wifibt copy into /vendor/lib/modules)
aic_ko=""
for dir in /vendor/lib/modules /system/lib/modules /lib/modules /usr/lib/modules; do
	[ -d "$dir" ] || continue
	if [ -f "$dir/aic8800_fdrv.ko" ] || [ -f "$dir/aic8800_bsp.ko" ]; then
		aic_ko=1
		break
	fi
	if find "$dir" -maxdepth 3 -name 'aic8800_fdrv.ko' 2>/dev/null | grep -q .; then
		aic_ko=1
		break
	fi
done
if [ -n "$aic_ko" ]; then
	pass "aic8800_*.ko present"
else
	fail "aic8800_fdrv.ko missing (enable ynh960 wifibt kernel config, rebuild kernel+rootfs)"
fi
if [ -x /usr/bin/rk_wifi_init ]; then
	pass "rk_wifi_init installed"
else
	warn "rk_wifi_init missing (manual aic8800 insmod still used)"
fi
if command -v hciattach >/dev/null 2>&1; then
	pass "hciattach installed"
else
	warn "hciattach missing (AIC BT UART attach may fail)"
fi
if [ -f /vendor/etc/firmware/fmacfw_8800d80_u02.bin ] || \
	[ -f /system/etc/firmware/fmacfw_8800d80_u02.bin ] || \
	[ -f /lib/firmware/fmacfw_8800d80_u02.bin ]; then
	pass "AIC8800D80 firmware present"
else
	warn "fmacfw_8800d80_u02.bin not found under firmware dirs"
fi
if [ -f /var/lib/wpa_supplicant/wpa_supplicant.conf ]; then
	pass "wpa_supplicant.conf seed present"
else
	warn "wpa_supplicant.conf seed missing (wifi-stack-up will create)"
fi
bt_daemon=""
for cand in /usr/libexec/bluetooth/bluetoothd /usr/sbin/bluetoothd /usr/bin/bluetoothd; do
	[ -x "$cand" ] && bt_daemon="$cand" && break
done
if [ -n "$bt_daemon" ] || command -v bluetoothd >/dev/null 2>&1; then
	pass "bluetoothd installed (${bt_daemon:-$(command -v bluetoothd)})"
else
	fail "bluetoothd missing (make apply-overlay && make build-rootfs; BlueZ 5.77 → /usr/libexec/bluetooth/bluetoothd)"
fi
if command -v bluetoothctl >/dev/null 2>&1 || [ -x /usr/bin/bluetoothctl ]; then
	pass "bluetoothctl installed"
else
	fail "bluetoothctl missing"
fi
bt_unit=""
for u in /usr/lib/systemd/system/bluetooth.service /lib/systemd/system/bluetooth.service /etc/systemd/system/bluetooth.service; do
	[ -f "$u" ] && bt_unit="$u" && break
done
if [ -n "$bt_unit" ]; then
	pass "bluetooth.service unit present"
else
	fail "bluetooth.service missing (bluez5_utils not installed)"
fi
if [ -f /etc/dbus-1/system.d/bluetooth.conf ] || \
	[ -f /usr/share/dbus-1/system.d/bluetooth.conf ]; then
	pass "dbus bluetooth.conf present (org.bluez policy)"
else
	fail "dbus bluetooth.conf missing (bluetoothd cannot own org.bluez)"
fi
if [ -d /lib/firmware ] && ls /lib/firmware/brcm/ >/dev/null 2>&1; then
	pass "Wi-Fi/BT firmware under /lib/firmware/brcm/"
elif [ -d /lib/firmware ]; then
	warn "no /lib/firmware/brcm/ — verify Wi-Fi/BT firmware for your module"
else
	warn "/lib/firmware missing"
fi
if command -v systemctl >/dev/null 2>&1; then
	for unit in wpa_supplicant.service network.service wifibt-init.service bluetooth.service dhcpcd.service; do
		unit_file=""
		for f in "/etc/systemd/system/$unit" "/usr/lib/systemd/system/$unit" "/lib/systemd/system/$unit"; do
			[ -f "$f" ] && unit_file="$f" && break
		done
		if [ -z "$unit_file" ]; then
			case "$unit" in
			bluetooth.service)
				fail "$unit unit file missing"
				;;
			dhcpcd.service)
				warn "$unit unit file missing (ok if package has no unit)"
				;;
			*)
				warn "$unit unit file missing"
				;;
			esac
			continue
		fi
		state="$(systemctl is-enabled "$unit" 2>/dev/null || echo disabled)"
		case "$state" in
		enabled|enabled-runtime)
			fail "$unit is enabled (should be boot-deferred)"
			;;
		static)
			pass "$unit static (on-demand; not in multi-user wants)"
			;;
		*)
			pass "$unit not enabled @ boot ($state)"
			;;
		esac
	done
fi
if pidof wpa_supplicant >/dev/null 2>&1; then
	warn "wpa_supplicant running @ check time (may be user-started)"
else
	pass "wpa_supplicant not running"
fi
if pidof bluetoothd >/dev/null 2>&1; then
	warn "bluetoothd running @ check time"
else
	pass "bluetoothd not running"
fi
if pidof dhcpcd >/dev/null 2>&1; then
	warn "dhcpcd running @ check time (may be user-started on wlan0)"
else
	pass "dhcpcd not running"
fi

echo ""
echo "--- GStreamer + MPP (P1 prep — rootfs when lws_hmi_gst_* enabled) ---"
if command -v gst-launch-1.0 >/dev/null 2>&1; then
	warn "gst-launch-1.0 on device (gst fragment enabled — OK for P5 prep)"
else
	prep_ok "GStreamer not in rootfs"
fi
mpp_ok=0
for lib in /usr/lib/librockchip_mpp.so* /usr/lib/libgst*.so*; do
	[ -e "$lib" ] || continue
	mpp_ok=1
done
if [ "$mpp_ok" -eq 1 ]; then
	warn "GStreamer/MPP libs present (early enable or prebuilt overlay)"
else
	prep_ok "MPP/GStreamer libs not in rootfs"
fi

echo ""
echo "--- mediamtx (P1 prep — binary may be staged; start only after IPC ping, §7.5) ---"
if [ -x /usr/bin/mediamtx ]; then
	pass "mediamtx binary staged in /usr/bin"
else
	prep_ok "mediamtx binary not in rootfs"
fi
if pidof mediamtx >/dev/null 2>&1; then
	fail "mediamtx process running (should not auto-start @ P1)"
else
	pass "mediamtx not running"
fi
if command -v systemctl >/dev/null 2>&1; then
	state="$(systemctl is-enabled mediamtx.service 2>/dev/null || echo disabled)"
	case "$state" in
	enabled|enabled-runtime)
		fail "mediamtx.service enabled ($state) — run: systemctl disable mediamtx.service"
		;;
	static)
		pass "mediamtx.service static (on-demand; no [Install])"
		;;
	*)
		pass "mediamtx.service not enabled @ boot ($state)"
		;;
	esac
fi
wants="/etc/systemd/system/multi-user.target.wants/mediamtx.service"
if [ -L "$wants" ] || [ -f "$wants" ]; then
	fail "mediamtx.service linked in multi-user.target.wants"
fi

echo ""
echo "--- platform libs (P1 prep — P2/P3/P5 via lws_hmi_platform*) ---"
for spec in \
	"libmodbus:/usr/lib/libmodbus.so*" \
	"yaml-cpp:/usr/lib/libyaml-cpp.so*" \
	"sqlite:/usr/lib/libsqlite3.so*" \
	"avahi:/usr/lib/libavahi*.so*"; do
	name="${spec%%:*}"
	glob="${spec#*:}"
	found=0
	# shellcheck disable=SC2086
	for f in $glob; do
		[ -e "$f" ] || continue
		found=1
		break
	done
	if [ "$found" -eq 1 ]; then
		warn "$name present on rootfs (platform fragment may be enabled early)"
	else
		prep_ok "$name not in rootfs"
	fi
done
if command -v modbus_connect >/dev/null 2>&1; then
	warn "modbus_connect CLI present"
fi

echo ""
echo "--- LCD / display params ---"
for f in /system/etc/960_lcd_param_rk356x.txt /system/etc/lcd_mipi_param.txt; do
	if [ -f "$f" ]; then
		pass "$(basename "$f") present"
	else
		fail "$f missing"
	fi
done

echo ""
if [ "$FAILED" -eq 0 ]; then
	echo "=== verify-env: ALL PASS ==="
	exit 0
fi
echo "=== verify-env: FAILED ==="
exit 1
