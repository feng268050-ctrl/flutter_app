#!/bin/sh
# Assert product hostname early (Rockchip post-hostname uses $RK_CHIP-buildroot).
set -eu

NAME=buildroot
if grep -q 'lws.emulator=1' /proc/cmdline 2>/dev/null; then
	NAME=buildroot
elif [ -f /etc/hostname ]; then
	cur="$(tr -d '[:space:]' </etc/hostname || true)"
	[ -n "$cur" ] && NAME="$cur"
fi

echo "$NAME" >/etc/hostname
if [ -f /etc/hosts ]; then
	sed -i '/^127\.0\.1\.1/d' /etc/hosts
fi
echo "127.0.1.1	$NAME" >>/etc/hosts
hostname "$NAME" 2>/dev/null || true
echo "lws-hostname: $NAME"
