#!/bin/sh
# Foreground LAN/WLAN sshd for ssh-debug-lan.service (Type=simple).
# Listen only on eth0/wlan0 global IPv4 — never 0.0.0.0 — so USB plug-ssh can
# keep its own sshd on 192.168.55.1:22 at the same time.
set -eu

ensure=/usr/libexec/ssh/ensure-sshd-hostkeys.sh
[ -x "$ensure" ] && "$ensure"
mkdir -p /run/sshd
chmod 0755 /run/sshd 2>/dev/null || true

set --
for iface in eth0 wlan0; do
	[ -d "/sys/class/net/$iface" ] || continue
	# shellcheck disable=SC2013
	for cidr in $(ip -4 -o addr show dev "$iface" scope global 2>/dev/null | awk '{print $4}'); do
		addr="${cidr%/*}"
		[ -n "$addr" ] || continue
		# Never bind the USB ECM address (USB-SSH owns it).
		[ "$addr" = "192.168.55.1" ] && continue
		set -- "$@" -o "ListenAddress=$addr"
	done
done

if [ "$#" -eq 0 ]; then
	echo "lan-ssh-run: no eth0/wlan0 IPv4 address — bring up Ethernet/Wi-Fi first" >&2
	exit 1
fi

echo "lan-ssh-run: starting sshd $*" >&2
exec /usr/sbin/sshd -D -f /etc/ssh/sshd_config "$@" \
	-o PasswordAuthentication=yes \
	-o PermitRootLogin=yes
