#!/bin/bash -e

# Plan A: enable hmi.service only; disable non-critical units at image build time.

source "${RK_POST_HELPER:-$(dirname "$(realpath "$0")")/post-helper}"

[ "$POST_OS" = buildroot ] || exit 0

WANTS="$TARGET_DIR/etc/systemd/system/multi-user.target.wants"
SYSINIT_WANTS="$TARGET_DIR/etc/systemd/system/sysinit.target.wants"
mkdir -p "$WANTS" "$SYSINIT_WANTS"

link_unit() {
	local unit="$1"
	local path="/etc/systemd/system/$unit"
	ln -sf "$path" "$WANTS/$unit"
}

unlink_unit() {
	rm -f "$WANTS/$1"
}

# KPI path: display init early; flutter-pi after local-fs.
if [ -f "$TARGET_DIR/etc/systemd/system/lws-hmi-debug-boot.service" ]; then
	ln -sf "/etc/systemd/system/lws-hmi-debug-boot.service" \
		"$SYSINIT_WANTS/lws-hmi-debug-boot.service"
	echo "lws-hmi-systemd: enabled lws-hmi-debug-boot.service (sysinit.target)"
fi

if [ -f "$TARGET_DIR/etc/systemd/system/param-update.service" ]; then
	ln -sf "/etc/systemd/system/param-update.service" \
		"$SYSINIT_WANTS/param-update.service"
	echo "lws-hmi-systemd: enabled param-update.service (sysinit.target)"
fi

if [ -f "$TARGET_DIR/etc/systemd/system/mainserver.service" ]; then
	link_unit mainserver.service
	echo "lws-hmi-systemd: enabled mainserver.service"
fi

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
