#!/bin/sh
# Assert product hostname early (Rockchip post-hostname uses $RK_CHIP-buildroot).
set -eu
NAME=buildroot
if [ -f /etc/hostname ]; then
	cur=$(cat /etc/hostname)
	cur=$(echo "$cur" | tr -d ' \t\r\n')
	[ -n "$cur" ] && NAME=$cur
fi
echo "$NAME" >/etc/hostname
hostname "$NAME" 2>/dev/null || true
# Avoid sed -i here (can stall under some executor/SELinux setups).
if [ -f /etc/hosts ]; then
	grep -v '^127\.0\.1\.1' /etc/hosts > /etc/hosts.tmp 2>/dev/null || cp /etc/hosts /etc/hosts.tmp
	mv /etc/hosts.tmp /etc/hosts
fi
echo "127.0.1.1	$NAME" >>/etc/hosts
echo "lws-hostname: $NAME"
