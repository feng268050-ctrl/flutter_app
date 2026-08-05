#!/bin/sh
# §3.4 platform stack verification on ynh960 device (excludes HMI boot KPI).
# Run after flash: verify-env
# Canonical copy: overlay/.../rootfs-overlay/usr/libexec/board/env-verify.sh
set -u

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*"; FAILED=1; }
warn() { echo "WARN: $*"; }
prep_ok() { echo "PASS: $* (P1 prep-only — absent on rootfs is OK)"; }

FAILED=0

echo "=== verify-env (§3.4 platform stack, Weston + eLinux) ==="

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
if [ -L /opt/hmi/data/icudtl.dat ]; then
	icu_link="$(readlink -f /opt/hmi/data/icudtl.dat 2>/dev/null || true)"
	case "$icu_link" in
	/usr/share/flutter/*)
		pass "bundle icudtl.dat symlink → system icu"
		;;
	*)
		fail "/opt/hmi/data/icudtl.dat symlink must resolve under /usr/share/flutter (got ${icu_link:-unresolved})"
		;;
	esac
elif [ -e /opt/hmi/data/icudtl.dat ]; then
	fail "/opt/hmi/data/icudtl.dat is a real file (use symlink or omit; ICU lives under /usr/share/flutter)"
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
if pidof flutter-wayland-client >/dev/null 2>&1 || pidof flutter-waylan >/dev/null 2>&1; then
	pass "flutter-wayland-client running"
else
	warn "flutter-wayland-client not running"
fi

echo ""
echo "--- keyboard runtime (xkb + Compose) ---"
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
	warn "/etc/default/keyboard missing (embedder uses built-in defaults)"
fi

echo ""
echo "--- RockUSB Loader reboot helper ---"
if [ -x /usr/libexec/board/reboot-loader ] && [ -x /usr/bin/reboot-loader ]; then
	pass "reboot-loader installed in PATH (RESTART2 loader — not busybox reboot)"
else
	fail "reboot-loader missing from /usr/libexec/board or /usr/bin"
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
echo "--- GPU / display libs (Mali, libdrm) ---"
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
echo "--- network stack (D11: networkd L3 + wpa D-Bus L2) ---"
if command -v wpa_supplicant >/dev/null 2>&1; then
	pass "wpa_supplicant installed"
else
	fail "wpa_supplicant missing"
fi
if ! /usr/sbin/wpa_supplicant -h 2>&1 | grep -q -- '[[:space:]]-u[[:space:]]'; then
	fail "wpa_supplicant missing -u (BR2_PACKAGE_WPA_SUPPLICANT_DBUS; br-make-packages wpa wpa_supplicant)"
else
	pass "wpa_supplicant has D-Bus (-u)"
fi
if command -v wpa_cli >/dev/null 2>&1; then
	pass "wpa_cli installed"
else
	fail "wpa_cli missing"
fi
if command -v networkctl >/dev/null 2>&1; then
	pass "networkctl installed (systemd-networkd)"
else
	fail "networkctl missing (BR2_PACKAGE_SYSTEMD_NETWORKD; br-make-packages systemd systemd)"
fi
netd_bin=""
for p in /lib/systemd/systemd-networkd /usr/lib/systemd/systemd-networkd; do
	if [ -x "$p" ]; then
		netd_bin=$p
		break
	fi
done
if [ -n "$netd_bin" ]; then
	pass "systemd-networkd binary ($netd_bin)"
else
	fail "systemd-networkd binary missing"
fi
if systemctl cat systemd-networkd.service >/dev/null 2>&1; then
	pass "systemd-networkd.service unit present"
else
	fail "systemd-networkd.service unit missing"
fi
if systemctl is-enabled systemd-networkd.service >/dev/null 2>&1; then
	pass "systemd-networkd.service enabled"
else
	fail "systemd-networkd.service not enabled (preset 99-appliance)"
fi
resolved_bin=""
for p in /lib/systemd/systemd-resolved /usr/lib/systemd/systemd-resolved; do
	if [ -x "$p" ]; then
		resolved_bin=$p
		break
	fi
done
if [ -n "$resolved_bin" ]; then
	pass "systemd-resolved binary ($resolved_bin)"
else
	fail "systemd-resolved binary missing (BR2_PACKAGE_SYSTEMD_RESOLVED; br-make-packages systemd systemd)"
fi
if systemctl cat systemd-resolved.service >/dev/null 2>&1; then
	pass "systemd-resolved.service unit present"
else
	fail "systemd-resolved.service unit missing"
fi
if systemctl is-enabled systemd-resolved.service >/dev/null 2>&1; then
	pass "systemd-resolved.service enabled"
else
	fail "systemd-resolved.service not enabled (preset 99-appliance)"
fi
timesyncd_bin=""
for p in /lib/systemd/systemd-timesyncd /usr/lib/systemd/systemd-timesyncd; do
	if [ -x "$p" ]; then
		timesyncd_bin=$p
		break
	fi
done
if [ -n "$timesyncd_bin" ]; then
	pass "systemd-timesyncd binary ($timesyncd_bin)"
else
	fail "systemd-timesyncd binary missing (BR2_PACKAGE_SYSTEMD_TIMESYNCD; br-make-packages systemd systemd)"
fi
if systemctl cat systemd-timesyncd.service >/dev/null 2>&1; then
	pass "systemd-timesyncd.service unit present"
else
	fail "systemd-timesyncd.service unit missing"
fi
# Preset enables timesyncd at boot — Settings Automatic is on by default.
# Manual mode / setWallClock calls timedatectl set-ntp false (stops the unit).
# Offline wall clock still uses external PCF8563 (rtc0) + rtc-systohc.
if systemctl is-enabled systemd-timesyncd.service >/dev/null 2>&1; then
	pass "systemd-timesyncd.service enabled by preset (Automatic NTP default on)"
else
	warn "systemd-timesyncd.service disabled (product default is enabled; Automatic on)"
fi
if [ -L /etc/resolv.conf ]; then
	_resolv_link="$(readlink /etc/resolv.conf)"
	case "$_resolv_link" in
	*systemd/resolve/*)
		pass "/etc/resolv.conf → resolved ($_resolv_link)"
		;;
	*)
		fail "/etc/resolv.conf must point at systemd-resolved (got $_resolv_link)"
		;;
	esac
else
	fail "/etc/resolv.conf must be a symlink to systemd-resolved"
fi
if grep -qE 'sync_resolv|wrote DNS to' /usr/libexec/network/networkd-apply-ipv4.sh 2>/dev/null; then
	fail "networkd-apply-ipv4.sh must not hand-write resolv.conf (use systemd-resolved)"
else
	pass "networkd-apply-ipv4.sh does not write resolv.conf"
fi
if systemctl is-active dbus.service >/dev/null 2>&1 || \
	systemctl is-active dbus.socket >/dev/null 2>&1; then
	pass "dbus active"
else
	fail "dbus not active (required for wpa/networkd D-Bus)"
fi
# Soft: name may be absent until Wi‑Fi/networkd started — unit/binary checks above are hard.
if busctl status org.freedesktop.network1 >/dev/null 2>&1; then
	pass "org.freedesktop.network1 on bus"
else
	# networkd may be idle until first apply; still require the unit to be startable.
	if systemctl start systemd-networkd.service >/dev/null 2>&1 && \
		busctl status org.freedesktop.network1 >/dev/null 2>&1; then
		pass "org.freedesktop.network1 on bus (after start)"
	else
		fail "org.freedesktop.network1 unavailable (networkd D-Bus)"
	fi
fi
if busctl status org.freedesktop.resolve1 >/dev/null 2>&1; then
	pass "org.freedesktop.resolve1 on bus"
else
	if systemctl start systemd-resolved.service >/dev/null 2>&1 && \
		busctl status org.freedesktop.resolve1 >/dev/null 2>&1; then
		pass "org.freedesktop.resolve1 on bus (after start)"
	else
		fail "org.freedesktop.resolve1 unavailable (systemd-resolved D-Bus)"
	fi
fi
if command -v dhcpcd >/dev/null 2>&1; then
	fail "dhcpcd present — L3 must be networkd only (unset BR2_PACKAGE_DHCPCD, rebuild rootfs)"
fi
if grep -qE '(^|[[:space:]])udhcpc([[:space:]]|$)|apply_legacy|legacy_dhcp' \
	/usr/libexec/network/networkd-apply-ipv4.sh 2>/dev/null; then
	fail "networkd-apply-ipv4.sh still has legacy DHCP fallback (D11)"
else
	pass "networkd-apply-ipv4.sh is networkd-only"
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
for helper in wifi-stack-up.sh wifi-stack-down.sh wlan0-dhcp.sh wlan0-static.sh run-wpa.sh; do
	if [ -x "/usr/libexec/wpa/$helper" ]; then
		pass "helper $helper"
	else
		fail "helper $helper missing or not executable (/usr/libexec/wpa/)"
	fi
done
# time-sync script retired — HAL LinuxDateTimeController owns network clock ladder
pass "helper time-sync (HAL inline; no /usr/bin/sync-time)"
for helper in eth0-dhcp.sh eth0-static.sh eth0-link.sh apply-eth0.sh networkd-apply-ipv4.sh; do
	if [ -x "/usr/libexec/network/$helper" ]; then
		pass "helper $helper"
	else
		fail "helper $helper missing or not executable (/usr/libexec/network/)"
	fi
done
for helper in bt-stack-up.sh bt-stack-down.sh bt-pair-agent.sh bt-ensure-agent.sh bt-set-alias.sh bt-trust-paired.sh wifibt-bringup.sh; do
	if [ -x "/usr/libexec/bluetooth/$helper" ]; then
		pass "helper $helper"
	else
		fail "helper $helper missing or not executable (/usr/libexec/bluetooth/)"
	fi
done
# W2: board modem/OTG/display-init live under OEM; rootfs keeps thin stubs.
# No oem-fallback — missing OEM helpers is a hard fail when /oem is mounted.
if [ -f /run/hmi/oem.env ]; then
	# shellcheck source=/dev/null
	. /run/hmi/oem.env
fi
if [ -f /run/hmi/oem.env ] && grep -q '^OEM_MIGRATE_FALLBACK=1' /run/hmi/oem.env 2>/dev/null; then
	fail "OEM_MIGRATE_FALLBACK set — rootfs fallback must not be used"
fi
if [ -f /run/hmi/oem.env ]; then
	src="$(grep -E '^OEM_SOURCE=' /run/hmi/oem.env 2>/dev/null | head -1 | cut -d= -f2-)"
	if [ "$src" = "partition" ]; then
		pass "OEM_SOURCE=partition"
	else
		fail "OEM_SOURCE expected partition (got '${src:-empty}')"
	fi
fi
for oem_helper in \
	"${WIFI_MODEM_HELPER:-/oem/boards/ynh960/helpers/wifibt-bringup.sh}" \
	"${USB_OTG_MODE_HELPER:-/oem/boards/ynh960/helpers/usb-otg-mode.sh}" \
	"/oem/boards/ynh960/helpers/display-init.sh"; do
	if [ -x "$oem_helper" ]; then
		pass "OEM helper $(basename "$oem_helper")"
	elif [ -d /oem/boards ]; then
		fail "OEM helper missing or not executable ($oem_helper)"
	else
		fail "OEM not mounted — cannot verify $oem_helper (flash/upgrade oem.img)"
	fi
done
if [ -x /usr/libexec/usb/usb-otg-mode.sh ] && [ -x /usr/libexec/display/ynh960-display-init.sh ]; then
	pass "rootfs OEM helper stubs (usb-otg-mode / ynh960-display-init)"
else
	fail "rootfs OEM helper stubs missing under /usr/libexec/usb/ or /usr/libexec/display/"
fi
for helper_path in \
	/usr/libexec/display/change-orientation.sh \
	/usr/libexec/board/bind-prefs.sh; do
	helper="$(basename "$helper_path")"
	if [ -x "$helper_path" ]; then
		pass "helper $helper"
	else
		fail "helper $helper missing or not executable ($helper_path)"
	fi
done
year="$(date -u +%Y 2>/dev/null || echo 0)"
case "$year" in
2025|2026|2027|2028|2029|2030)
	pass "wall clock year=$year"
	;;
*)
	warn "wall clock year=$year (HTTPS certs may fail until HAL time sync after network)"
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
# Combo firmware: OEM radio pack (not rootfs kitchen sink /lib/firmware/brcm).
OEM_RADIO_FW="${OEM_RADIO_FW:-/oem/boards/ynh960/radio/firmware}"
if [ -f "$OEM_RADIO_FW/fmacfw_8800d80_u02.bin" ]; then
	pass "OEM radio AIC8800D80 firmware ($OEM_RADIO_FW)"
elif [ -f /vendor/etc/firmware/fmacfw_8800d80_u02.bin ] || \
	[ -f /system/etc/firmware/fmacfw_8800d80_u02.bin ] || \
	[ -f /lib/firmware/fmacfw_8800d80_u02.bin ]; then
	# Symlink from bringup into AIC_FW_PATH still OK if target is OEM.
	_fw=""
	for cand in /vendor/etc/firmware /system/etc/firmware /lib/firmware; do
		[ -f "$cand/fmacfw_8800d80_u02.bin" ] || continue
		_fw="$cand/fmacfw_8800d80_u02.bin"
		break
	done
	if [ -n "$_fw" ] && [ -L "$_fw" ]; then
		pass "AIC8800D80 firmware linked at $_fw → $(readlink "$_fw")"
	else
		warn "fmacfw_8800d80_u02.bin under firmware dirs but OEM radio pack missing ($OEM_RADIO_FW)"
	fi
	unset _fw
else
	fail "OEM radio firmware missing ($OEM_RADIO_FW/fmacfw_8800d80_u02.bin) — make build-oem && OEM_ONLY=1 make upgrade"
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
	for unit in wpa_supplicant.service network.service wifibt-init.service bluetooth.service; do
		unit_file=""
		for f in "/etc/systemd/system/$unit" "/usr/lib/systemd/system/$unit" "/lib/systemd/system/$unit"; do
			[ -e "$f" ] && unit_file="$f" && break
		done
		if [ -z "$unit_file" ]; then
			case "$unit" in
			bluetooth.service)
				fail "$unit unit file missing"
				;;
			*)
				warn "$unit unit file missing"
				;;
			esac
			continue
		fi
		# Masked units are symlinks to /dev/null — treat as correctly suppressed.
		if [ -L "$unit_file" ] && [ "$(readlink -f "$unit_file" 2>/dev/null)" = "/dev/null" ]; then
			pass "$unit masked (D11: use wlan-wpa.service for Wi‑Fi)"
			continue
		fi
		[ -f "$unit_file" ] || { warn "$unit unit file missing"; continue; }
		state="$(systemctl is-enabled "$unit" 2>/dev/null || echo disabled)"
		case "$state" in
		enabled|enabled-runtime)
			# bluetooth.service: Alias=dbus-org.bluez.service makes is-enabled=enabled
			# even when boot-deferred (no *.wants link). That alias is intentional.
			if [ "$unit" = "bluetooth.service" ]; then
				wants_link=""
				for wants_dir in /etc/systemd/system/*.wants /usr/lib/systemd/system/*.wants; do
					[ -d "$wants_dir" ] || continue
					if [ -e "$wants_dir/$unit" ]; then
						wants_link="$wants_dir/$unit"
						break
					fi
				done
				if [ -n "$wants_link" ]; then
					fail "$unit linked at boot ($wants_link)"
				else
					pass "$unit boot-deferred (is-enabled=alias-only for dbus-org.bluez)"
				fi
			else
				fail "$unit is enabled (should be boot-deferred or masked)"
			fi
			;;
		masked)
			pass "$unit masked"
			;;
		static)
			pass "$unit static (on-demand; not in multi-user wants)"
			;;
		*)
			pass "$unit not enabled @ boot ($state)"
			;;
		esac
	done
	if [ -f /etc/systemd/system/dhcpcd.service ] || \
		[ -f /usr/lib/systemd/system/dhcpcd.service ] || \
		[ -f /lib/systemd/system/dhcpcd.service ]; then
		fail "dhcpcd.service unit present — remove dhcpcd from image (D11)"
	else
		pass "dhcpcd.service absent"
	fi
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
	fail "dhcpcd running — L3 must be networkd only (D11)"
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
echo "--- mediamtx (App-owned under /opt/hmi/bin; not a rootfs unit) ---"
if [ -x /usr/bin/mediamtx ]; then
	fail "/usr/bin/mediamtx still in rootfs (should be /opt/hmi/bin/mediamtx)"
else
	pass "/usr/bin/mediamtx absent from rootfs"
fi
if [ -e /etc/systemd/system/mediamtx.service ]; then
	fail "mediamtx.service still present in rootfs"
else
	pass "mediamtx.service absent"
fi
if [ -x /opt/hmi/bin/mediamtx ]; then
	pass "App mediamtx at /opt/hmi/bin/mediamtx"
else
	prep_ok "App mediamtx not installed yet (make build-app / push-app)"
fi
wants="/etc/systemd/system/multi-user.target.wants/mediamtx.service"
if [ -L "$wants" ] || [ -f "$wants" ]; then
	fail "mediamtx.service linked in multi-user.target.wants"
else
	pass "mediamtx.service not in multi-user wants"
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
if [ -x /usr/sbin/avahi-daemon ]; then
	if grep -q '^avahi:' /etc/passwd 2>/dev/null; then
		prep_ok "avahi system user present"
	else
		fail "avahi-daemon installed but user 'avahi' missing (prebuilt users table / post-build)"
	fi
fi
if command -v modbus_connect >/dev/null 2>&1; then
	warn "modbus_connect CLI present"
fi

echo ""
echo "--- LCD / display params ---"
oem_lcd=""
if [ -f /oem/manifest.json ]; then
	sp="$(sed -n 's/.*"screen_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' /oem/manifest.json | head -1)"
	[ -n "$sp" ] && [ -d "/oem/$sp/lcd" ] && oem_lcd="/oem/$sp/lcd"
fi
if [ -z "$oem_lcd" ]; then
	fail "OEM screen lcd/ missing — required (no /system/etc seed fallback)"
else
	for f in 960_lcd_param_rk356x.txt lcd_mipi_param.txt; do
		if [ -f "$oem_lcd/$f" ]; then
			pass "OEM lcd $(basename "$f")"
		else
			fail "$oem_lcd/$f missing"
		fi
	done
fi
for f in /system/etc/960_lcd_param_rk356x.txt /system/etc/lcd_mipi_param.txt; do
	if [ -f "$f" ]; then
		warn "$(basename "$f") still in /system/etc (unused at runtime; OEM lcd is authority)"
	fi
done

echo ""
if [ "$FAILED" -eq 0 ]; then
	echo "=== verify-env: ALL PASS ==="
	exit 0
fi
echo "=== verify-env: FAILED ==="
exit 1
