#!/bin/bash -e

# Plan A: enable hmi.service only; disable non-critical units at image build time.

source "${RK_POST_HELPER:-$(dirname "$(realpath "$0")")/post-helper}"

[ "$POST_OS" = buildroot ] || exit 0

WANTS="$TARGET_DIR/etc/systemd/system/multi-user.target.wants"
mkdir -p "$WANTS"

link_unit() {
	local unit="$1"
	local path="/etc/systemd/system/$unit"
	ln -sf "$path" "$WANTS/$unit"
}

unlink_unit() {
	rm -f "$WANTS/$1"
}

# KPI path: flutter-pi starts after local-fs only.
if [ -f "$TARGET_DIR/etc/systemd/system/hmi.service" ]; then
	link_unit hmi.service
	echo "lws-hmi-systemd: enabled hmi.service"
fi

# Do not block boot KPI; start after home or from App (§6.4).
for unit in mediamtx.service sshd.service bluetooth.service; do
	if [ -f "$TARGET_DIR/etc/systemd/system/$unit" ]; then
		unlink_unit "$unit"
		echo "lws-hmi-systemd: disabled $unit (not in multi-user.wants)"
	fi
done
