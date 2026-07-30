#!/bin/sh
# Plan A boot KPI verification — run on ynh960 device (serial shell or ssh after §7.7).
# Shipped via rootfs-overlay (BR2_ROOTFS_OVERLAY).
set -u

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*"; FAILED=1; }
warn() { echo "WARN: $*"; }

FAILED=0
WANTS=/etc/systemd/system/multi-user.target.wants

echo "=== verify-boot (Plan A / single image) ==="

echo ""
echo "--- multi-user.target.wants ---"
if [ -d "$WANTS" ]; then
	ls -la "$WANTS" 2>/dev/null || true
else
	fail "missing $WANTS"
fi

for unit in lws-hmi-debug-boot.service ssh-debug-usb.service sshd.service sshd.socket ssh-debug-lan.service wlan-wpa.service wlan-dhcp.service eth0-network.service bluetooth.service wifibt-init.service wpa_supplicant.service network.service log-guardian.service; do
	if [ -e "$WANTS/$unit" ]; then
		fail "$unit still enabled in multi-user.target.wants"
	else
		pass "$unit not in multi-user.target.wants"
	fi
done

for unit in lws-hmi-debug-boot.service wifibt-init.service log-guardian.service usbdevice.service; do
	if [ -e /etc/systemd/system/sysinit.target.wants/$unit ]; then
		fail "$unit still enabled in sysinit.target.wants"
	else
		pass "$unit not in sysinit.target.wants"
	fi
done

echo ""
echo "--- Rockchip usbdevice (conflicts with USB plug-ssh ECM) ---"
if [ -x /usr/bin/usbdevice ]; then
	fail "/usr/bin/usbdevice still present"
else
	pass "/usr/bin/usbdevice absent"
fi
if [ -e /etc/systemd/system/usbdevice.service ] && \
	[ "$(readlink /etc/systemd/system/usbdevice.service 2>/dev/null)" != "/dev/null" ]; then
	fail "usbdevice.service not masked"
else
	pass "usbdevice.service masked or absent"
fi
if [ -d /sys/kernel/config/usb_gadget/rockchip ]; then
	warn "configfs gadget rockchip still present (UDC may be busy until replug)"
else
	pass "no rockchip configfs gadget"
fi

for unit in hmi.service oem-compose.service mainserver.service cpu-performance.service pwrkey-poweroff.service ; do
	if [ -e "$WANTS/$unit" ]; then
		pass "$unit enabled"
	else
		fail "$unit missing from multi-user.target.wants"
	fi
done

echo ""
echo "--- other *.wants (sshd.socket etc.) ---"
for unit in lws-hmi-debug-boot.service ssh-debug-usb.service sshd.service sshd.socket bluetooth.service wifibt-init.service wpa_supplicant.service network.service log-guardian.service wlan-wpa.service wlan-dhcp.service eth0-network.service; do
	found=""
	for wants_dir in /etc/systemd/system/*.wants; do
		[ -d "$wants_dir" ] || continue
		if [ -e "$wants_dir/$unit" ]; then
			found="$wants_dir"
		fi
	done
	if [ -n "$found" ]; then
		fail "$unit still linked under $found"
	else
		pass "$unit not linked under any *.wants"
	fi
done

echo ""
echo "--- retired debug-boot ---"
if [ -f /usr/libexec/hmi/debug-boot.sh ] || [ -f /etc/systemd/system/lws-hmi-debug-boot.service ]; then
	fail "debug-boot artifacts still present"
else
	pass "debug-boot removed"
fi
if [ -e /etc/systemd/system/sysinit.target.wants/lws-hmi-debug-boot.service ]; then
	fail "debug-boot still enabled in sysinit.target.wants"
else
	pass "debug-boot not in sysinit.target.wants"
fi

echo ""
echo "--- port 22 ---"
USB_SSH_ADDR="${LWS_HMI_USB_SSH_ADDR:-192.168.55.1}"
lan_debug_on=0
if systemctl is-active --quiet ssh-debug-lan.service 2>/dev/null; then
	lan_debug_on=1
fi
if [ -e /etc/systemd/system/multi-user.target.wants/ssh-debug-lan.service ]; then
	fail "ssh-debug-lan.service enabled in multi-user.target.wants (must be on-demand only)"
else
	pass "ssh-debug-lan.service not in multi-user.target.wants"
fi
if [ -n "${SSH_CONNECTION:-}" ]; then
	warn "SSH session active — skip port 22 check (use serial ttyFIQ0 for accurate boot KPI)"
elif command -v ss >/dev/null 2>&1; then
	listeners="$(ss -lntp 2>/dev/null | grep -E '(:|\])22\s' || true)"
	if [ -z "$listeners" ]; then
		pass "port 22 not listening"
	else
		echo "$listeners"
		if [ "$lan_debug_on" -eq 1 ]; then
			warn "port 22 listening (LAN SSH debug via ssh-debug-lan.service)"
		elif echo "$listeners" | grep -qE '0\.0\.0\.0:22|\*:22|\[::\]:22|127\.0\.0\.1:22'; then
			fail "sshd listening on LAN/all interfaces (expected usb0-only or closed; run disable-ssh-debug.sh)"
		elif echo "$listeners" | grep -qvE "${USB_SSH_ADDR}:22|${USB_SSH_ADDR}\]:22"; then
			fail "sshd listening on port 22 outside USB plug-ssh (${USB_SSH_ADDR})"
		else
			pass "port 22 listening on USB plug-ssh only (${USB_SSH_ADDR})"
		fi
	fi
elif command -v netstat >/dev/null 2>&1; then
	listeners="$(netstat -lntp 2>/dev/null | grep -E '(:|\])22\s' || true)"
	if [ -z "$listeners" ]; then
		pass "port 22 not listening"
	elif [ "$lan_debug_on" -eq 1 ]; then
		echo "$listeners"
		warn "port 22 listening (LAN SSH debug via ssh-debug-lan.service)"
	elif echo "$listeners" | grep -qE '0\.0\.0\.0:22|127\.0\.0\.1:22|\*:22'; then
		echo "$listeners"
		fail "sshd listening on LAN/all interfaces (expected usb0-only or closed; run disable-ssh-debug.sh)"
	elif echo "$listeners" | grep -q "${USB_SSH_ADDR}:22"; then
		echo "$listeners"
		pass "port 22 listening on USB plug-ssh only (${USB_SSH_ADDR})"
	else
		echo "$listeners"
		fail "port 22 in use (see netstat output above)"
	fi
else
	warn "ss/netstat not available — skip port 22 check"
fi

if [ -z "${SSH_CONNECTION:-}" ] && command -v systemctl >/dev/null 2>&1; then
	for unit in sshd.service sshd.socket; do
		state="$(systemctl is-active "$unit" 2>/dev/null || echo inactive)"
		case "$state" in
		active|activating)
			fail "$unit is $state"
			;;
		esac
	done
fi

echo ""
echo "--- pwrkey poweroff ---"
pwrkey_found=0
for name_file in /sys/class/input/event*/device/name; do
	[ -r "$name_file" ] || continue
	name="$(cat "$name_file" 2>/dev/null || echo unknown)"
	name_lc="$(echo "$name" | tr '[:upper:]' '[:lower:]')"
	case "$name_lc" in
		*pwr*key*|*power*key*|*power\ button*|*gpio-keys*|*adc-keys*|*rk8*pwr*)
			pass "power-key input device present: $name"
			pwrkey_found=1
			;;
	esac
done
if [ "$pwrkey_found" -eq 0 ]; then
	fail "no pwrkey/gpio-keys input device found"
fi
if command -v systemctl >/dev/null 2>&1; then
	state="$(systemctl is-active pwrkey-poweroff.service 2>/dev/null || echo inactive)"
	case "$state" in
	active)
		pass "pwrkey-poweroff.service active"
		;;
	*)
		fail "pwrkey-poweroff.service is $state"
		;;
	esac
	state="$(systemctl is-active input-event-daemon.service 2>/dev/null || echo inactive)"
	case "$state" in
	active|activating)
		fail "input-event-daemon.service is $state (conflicts with pwrkey poweroff)"
		;;
	*)
		pass "input-event-daemon.service inactive"
		;;
	esac
fi
if [ -x /usr/libexec/hmi/pre-poweroff.sh ]; then
	pass "pre-poweroff.sh present and executable"
else
	fail "pre-poweroff.sh missing or not executable"
fi
if [ -x /usr/libexec/hmi/shutdown.sh ]; then
	pass "shutdown.sh present and executable"
else
	fail "shutdown.sh missing or not executable"
fi
case "$(readlink /usr/bin/systemctl 2>/dev/null)" in
../libexec/hmi/systemctl-poweroff-wrapper.sh)
	wrap_ok=1 ;;
esac
if [ -x /usr/bin/systemctl.real ] && [ "${wrap_ok:-0}" = 1 ] && [ -e /usr/bin/systemctl ]; then
	pass "/usr/bin/systemctl wrapped for graceful poweroff"
else
	fail "/usr/bin/systemctl wrapper missing (expected systemctl.real + wrapper symlink)"
fi
if [ -f /etc/systemd/system/systemd-poweroff.service.d/50-lws-hmi-pre-poweroff.conf ]; then
	fail "retired systemd-poweroff drop-in still present"
else
	pass "retired systemd-poweroff drop-in absent"
fi
if [ -e /etc/systemd/system/poweroff.target.wants/lws-hmi-pre-poweroff.service ]; then
	fail "retired pre-poweroff.service still linked in poweroff.target.wants"
else
	pass "retired pre-poweroff.service not in poweroff.target.wants"
fi

echo ""
echo "--- mediamtx (App-owned; no rootfs unit) ---"
if [ -e /etc/systemd/system/mediamtx.service ]; then
	fail "mediamtx.service still present"
else
	pass "mediamtx.service absent"
fi
if [ -x /usr/bin/mediamtx ]; then
	fail "/usr/bin/mediamtx still in rootfs"
else
	pass "/usr/bin/mediamtx absent"
fi

echo ""
echo "--- systemd-network-generator ---"
ng=/etc/systemd/system/systemd-network-generator.service
if [ -L "$ng" ] && [ "$(readlink "$ng" 2>/dev/null)" = "/dev/null" ]; then
	pass "systemd-network-generator masked"
else
	warn "systemd-network-generator not masked"
fi

echo ""
echo "--- performance governors ---"
if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
	cpu_gov="$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo unknown)"
	if [ "$cpu_gov" = performance ]; then
		pass "CPU cpufreq governor is performance"
	else
		warn "CPU cpufreq governor is $cpu_gov (expected performance)"
	fi
else
	warn "CPU cpufreq sysfs missing — skip governor check"
fi
if [ -d /sys/class/devfreq ]; then
	devfreq_ok=1
	for gov in /sys/class/devfreq/*/governor; do
		[ -f "$gov" ] || continue
		name="$(basename "$(dirname "$gov")")"
		cur="$(cat "$gov" 2>/dev/null || echo unknown)"
		echo "devfreq/$name: $cur"
		if [ "$cur" != performance ]; then
			devfreq_ok=0
		fi
	done
	if [ "$devfreq_ok" -eq 1 ]; then
		pass "all devfreq governors are performance"
	else
		warn "some devfreq governors are not performance"
	fi
else
	warn "devfreq sysfs missing — skip devfreq check"
fi

echo ""
echo "--- Weston client / hmi.service ---"
if pidof flutter-wayland-client >/dev/null 2>&1 || pidof flutter-waylan >/dev/null 2>&1; then
	pass "flutter-wayland-client running"
else
	warn "flutter-wayland-client not running"
fi
if command -v systemctl >/dev/null 2>&1; then
	state="$(systemctl is-active hmi.service 2>/dev/null || echo unknown)"
	echo "hmi.service: $state"
fi

echo ""
echo "--- systemd-analyze ---"
if command -v systemd-analyze >/dev/null 2>&1; then
	systemd-analyze 2>/dev/null | head -5 || true
	echo ""
	systemd-analyze critical-chain hmi.service 2>/dev/null || true
else
	warn "systemd-analyze not installed"
fi

echo ""
if [ "$FAILED" -eq 0 ]; then
	echo "=== verify-boot: ALL PASS ==="
	exit 0
fi
echo "=== verify-boot: FAILED ==="
exit 1
