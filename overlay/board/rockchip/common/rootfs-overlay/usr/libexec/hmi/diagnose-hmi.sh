#!/bin/sh
# HMI / platform smoke when UI misbehaves or make devices is empty.
set -u

fail=0
ok() { echo "OK: $*"; }
bad() { echo "FAIL: $*"; fail=1; }
warn() { echo "WARN: $*"; }

echo "=== diagnose-hmi ==="

echo ""
echo "--- retired paths (must be absent) ---"
if grep -r '/usr/lib/lws-hmi\|/var/lib/lws-hmi' /etc 2>/dev/null \
	| grep -v '^Binary' \
	| grep -v 'diagnose-hmi.sh:' \
	| head -5; then
	bad "etc/ still references /usr/lib/lws-hmi or /var/lib/lws-hmi (stale rootfs — reflash after make build-rootfs PASS)"
else
	ok "etc/ has no monolithic lws-hmi path refs"
fi
stale_etc_name=""
for f in /etc/lws-hmi /etc/*lws-hmi* /etc/*/*lws-hmi* /etc/*/*/*lws-hmi*; do
	[ -e "$f" ] || continue
	stale_etc_name="${stale_etc_name:+$stale_etc_name }$f"
done
if [ -n "$stale_etc_name" ]; then
	bad "etc/ still has lws-hmi basename(s): $stale_etc_name"
else
	ok "etc/ has no *lws-hmi* paths"
fi
if [ -d /userdata/lws-hmi ] && [ ! -L /userdata/lws-hmi ]; then
	warn "/userdata/lws-hmi still present (bind-prefs folds on next boot after upgrade)"
fi
for u in /etc/systemd/system/lws-hmi-*.service; do
	[ -e "$u" ] || continue
	bad "retired unit present: $u"
done
[ "$fail" -eq 0 ] && ok "no lws-hmi-*.service units"

echo ""
echo "--- userdata + prefs bind ---"
if mountpoint -q /userdata 2>/dev/null; then
	ok "/userdata mounted"
else
	warn "/userdata not a mountpoint (prefs on rootfs until GPT userdata exists)"
fi
for p in /var/lib/wpa_supplicant /var/lib/network /var/lib/bluetooth /var/lib/hal /var/lib/hmi; do
	if [ -L "$p" ]; then
		ok "$p -> $(readlink "$p")"
	elif [ -d "$p" ]; then
		warn "$p is a directory (bind-prefs may not have run)"
	else
		bad "$p missing"
	fi
done

echo ""
echo "--- operator commands ---"
for cmd in verify-env start-usb-ssh; do
	if [ -x "/usr/bin/$cmd" ]; then
		ok "/usr/bin/$cmd"
	else
		bad "/usr/bin/$cmd missing"
	fi
done

echo ""
echo "--- hmi.service ---"
systemctl is-active hmi.service 2>/dev/null || warn "hmi.service not active"
journalctl -u hmi.service -n 15 --no-pager 2>/dev/null || true

echo ""
echo "--- Wi-Fi stack (manual) ---"
if [ -x /usr/libexec/wpa/wifi-stack-up.sh ]; then
	if /usr/libexec/wpa/wifi-stack-up.sh; then
		ok "wifi-stack-up.sh"
	else
		bad "wifi-stack-up.sh failed (see wifi-stack-up / run-wpa / wifibt-bringup above)"
		systemctl status wlan-wpa.service --no-pager -l 2>/dev/null | head -20 || true
		tail -20 /var/lib/wpa_supplicant/wpa_supplicant.log 2>/dev/null || true
	fi
else
	bad "/usr/libexec/wpa/wifi-stack-up.sh missing"
fi

echo ""
echo "--- USB plug-ssh (make devices) ---"
if [ -x /usr/bin/usb-otg-mode ]; then
	usb-otg-mode status || true
else
	bad "usb-otg-mode missing"
fi
if [ -x /usr/bin/recover-usb-ssh ]; then
	echo "hint: plug Micro-USB to host, then: recover-usb-ssh"
fi
systemctl status ssh-debug-usb.service --no-pager -l 2>/dev/null | head -15 || true
ip -br addr show usb0 2>/dev/null || warn "usb0 down (no USB cable / VBUS / g_ether)"

echo ""
echo "--- bundle ---"
[ -f /opt/hmi/lib/libapp.so ] && ok "libapp.so" || bad "missing /opt/hmi/lib/libapp.so"
[ -f /usr/lib/libflutter_engine.so ] && ok "system engine" || bad "missing /usr/lib/libflutter_engine.so"

echo ""
if [ "$fail" -eq 0 ]; then
	echo "=== diagnose-hmi: PASS (see WARN for optional items) ==="
else
	echo "=== diagnose-hmi: FAIL ==="
	exit 1
fi
