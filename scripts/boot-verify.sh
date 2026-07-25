#!/bin/sh
# Plan A boot KPI verification — canonical copy in rootfs-overlay/usr/libexec/hmi/.
# This scripts/ copy is for editing; keep in sync with overlay before build-rootfs.
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

for unit in lws-hmi-debug-boot.service mediamtx.service sshd.service sshd.socket bluetooth.service; do
	if [ -e "$WANTS/$unit" ]; then
		fail "$unit still enabled in multi-user.target.wants"
	else
		pass "$unit not in multi-user.target.wants"
	fi
done

for unit in hmi.service mainserver.service; do
	if [ -e "$WANTS/$unit" ]; then
		pass "$unit enabled"
	else
		fail "$unit missing from multi-user.target.wants"
	fi
done

echo ""
echo "--- other *.wants (sshd.socket etc.) ---"
for unit in lws-hmi-debug-boot.service mediamtx.service sshd.service sshd.socket bluetooth.service; do
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
if [ -n "${SSH_CONNECTION:-}" ]; then
	warn "SSH session active — skip port 22 check (use serial ttyFIQ0 for accurate boot KPI)"
elif command -v ss >/dev/null 2>&1; then
	if ss -lntp 2>/dev/null | grep -E '(:|\])22\s' | grep -q .; then
		ss -lntp 2>/dev/null | grep -E '(:|\])22\s' || true
		if pidof sshd >/dev/null 2>&1; then
			fail "sshd listening on port 22"
		else
			fail "port 22 in use (see ss output above)"
		fi
	else
		pass "port 22 not listening"
	fi
elif command -v netstat >/dev/null 2>&1; then
	if netstat -lntp 2>/dev/null | grep -E '(:|\])22\s' | grep -q .; then
		fail "sshd listening on port 22"
	else
		pass "port 22 not listening"
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
echo "--- mediamtx ---"
if pidof mediamtx >/dev/null 2>&1; then
	fail "mediamtx process running"
else
	pass "mediamtx not running"
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
