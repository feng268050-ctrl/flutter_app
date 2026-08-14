#!/bin/sh
# Plan A: run after systemd preset-all during rootfs.ext2 fakeroot (see systemd.mk
# SYSTEMD_ROOTFS_PRE_CMD_HOOKS). Post-rootfs hooks clean BASE target/; preset-all
# re-enables units in the image copy — undo that here before mkfs.ext2.
set -eu

TARGET_DIR="${1:?TARGET_DIR required}"
SYSTEMD_DIR="$TARGET_DIR/etc/systemd/system"
WANTS="$SYSTEMD_DIR/multi-user.target.wants"
SYSINIT_WANTS="$SYSTEMD_DIR/sysinit.target.wants"

PURGE="$(dirname "$0")/purge-retired-rootfs-artifacts.sh"
if [ -f "$PURGE" ]; then
	sh "$PURGE" "$TARGET_DIR"
fi

disable_unit() {
	unit="$1"
	local wants_dir link
	for wants_dir in "$SYSTEMD_DIR"/*.wants \
		"$TARGET_DIR/usr/lib/systemd/system"/*.wants \
		"$TARGET_DIR/lib/systemd/system"/*.wants; do
		[ -d "$wants_dir" ] || continue
		link="$wants_dir/$unit"
		if [ -e "$link" ] || [ -L "$link" ]; then
			rm -f "$link"
		fi
	done
}

disable_unit mainserver.service

link_unit() {
	unit="$1"
	[ -f "$SYSTEMD_DIR/$unit" ] || return 0
	mkdir -p "$WANTS"
	ln -sf "/etc/systemd/system/$unit" "$WANTS/$unit"
}

link_unit_sysinit() {
	unit="$1"
	[ -f "$SYSTEMD_DIR/$unit" ] || return 0
	mkdir -p "$SYSINIT_WANTS"
	ln -sf "/etc/systemd/system/$unit" "$SYSINIT_WANTS/$unit"
}

for unit in input-event-daemon.service sshd.service sshd.socket bluetooth.service wifibt-init.service wpa_supplicant.service network.service dhcpcd.service log-guardian.service usbdevice.service ssh-debug-lan.service wlan-wpa.service wlan-dhcp.service eth0-network.service; do
	disable_unit "$unit"
done

# preset-all may re-link units with [Install]; explicit disable clears all wants.
if command -v systemctl >/dev/null 2>&1; then
	for unit in input-event-daemon.service sshd.service sshd.socket bluetooth.service wifibt-init.service wpa_supplicant.service network.service dhcpcd.service log-guardian.service usbdevice.service ssh-debug-lan.service wlan-wpa.service wlan-dhcp.service eth0-network.service; do
		systemctl --root="$TARGET_DIR" disable "$unit" >/dev/null 2>&1 || true
	done
	systemctl --root="$TARGET_DIR" mask usbdevice.service >/dev/null 2>&1 || true
	systemctl --root="$TARGET_DIR" mask wpa_supplicant.service >/dev/null 2>&1 || true
fi

ln -sf /dev/null "$SYSTEMD_DIR/usbdevice.service"
# Keep stock D-Bus wpa masked across preset-all (see 06-systemd.sh).
ln -sf /dev/null "$SYSTEMD_DIR/wpa_supplicant.service"
rm -f \
	"$TARGET_DIR/usr/bin/usbdevice" \
	"$TARGET_DIR/lib/udev/rules.d/61-usbdevice.rules" \
	"$TARGET_DIR/etc/profile.d/usbdevice.sh" \
	"$TARGET_DIR/usr/lib/systemd/system/usbdevice.service" \
	"$TARGET_DIR/lib/systemd/system/usbdevice.service"

# D11: L3 is networkd-only — purge leftover dhcpcd from older builds.
rm -f \
	"$TARGET_DIR/usr/sbin/dhcpcd" \
	"$TARGET_DIR/sbin/dhcpcd" \
	"$TARGET_DIR/etc/dhcpcd.conf" \
	"$TARGET_DIR/usr/lib/systemd/system/dhcpcd.service" \
	"$TARGET_DIR/lib/systemd/system/dhcpcd.service" \
	"$TARGET_DIR/etc/systemd/system/dhcpcd.service"
rm -rf \
	"$TARGET_DIR/usr/share/dhcpcd" \
	"$TARGET_DIR/var/db/dhcpcd" \
	"$TARGET_DIR/etc/systemd/system/dhcpcd.service.d" \
	2>/dev/null || true


rm -f \
	"$TARGET_DIR/usr/libexec/hmi/debug-boot.sh" \
	"$TARGET_DIR/usr/libexec/hmi/stop-hmi.sh" \
	"$TARGET_DIR/usr/libexec/hmi/push-app-apply-and-reboot.sh"
rmdir \
	"$TARGET_DIR/etc/systemd/system/systemd-poweroff.service.d" \
	"$TARGET_DIR/etc/systemd/system/systemd-halt.service.d" \
	"$TARGET_DIR/etc/systemd/system/systemd-reboot.service.d" \
	2>/dev/null || true

link_unit cpu-performance.service
link_unit_sysinit cpu-performance.service
link_unit serial-stty.service
link_unit pwrkey-poweroff.service
link_unit ab-boot-confirm.service
link_unit oem-compose.service
link_unit_sysinit oem-compose.service
link_unit tee-supplicant.service
link_unit usb-otg-role-boot.service
link_unit hmi.service
link_unit_sysinit hmi.service
# Display init stays sysinit-only (already linked by 06-systemd / unit Install).
if [ -f "$SYSTEMD_DIR/storage-init.service" ]; then
	mkdir -p "$SYSINIT_WANTS"
	ln -sf "/etc/systemd/system/storage-init.service" \
		"$SYSINIT_WANTS/storage-init.service"
fi

ln -sf /dev/null "$SYSTEMD_DIR/systemd-network-generator.service"

# D11: glibc DNS via systemd-resolved (Buildroot systemd also sets this when
# BR2_PACKAGE_SYSTEMD_RESOLVED=y; reinforce after overlay / preset-all).
ln -sfn ../run/systemd/resolve/resolv.conf "$TARGET_DIR/etc/resolv.conf"

SYNC_ENGINE="$(dirname "$0")/sync-flutter-engine.sh"
if [ -f "$SYNC_ENGINE" ]; then
	sh "$SYNC_ENGINE" "$TARGET_DIR"
fi

SYNC_ELINUX="$(dirname "$0")/sync-flutter-embedded-linux.sh"
if [ -f "$SYNC_ELINUX" ]; then
	sh "$SYNC_ELINUX" "$TARGET_DIR"
fi

DOCKER_ROOT="${DOCKER_ROOT:-/work/lws-hmi}"
ENSURE_KEYS="$TARGET_DIR/usr/libexec/ssh/ensure-sshd-hostkeys.sh"
if [ ! -f "$ENSURE_KEYS" ]; then
	ENSURE_KEYS="$DOCKER_ROOT/overlay/board/rockchip/common/rootfs-overlay/usr/libexec/ssh/ensure-sshd-hostkeys.sh"
fi
if [ -f "$ENSURE_KEYS" ]; then
	sh "$ENSURE_KEYS" "$TARGET_DIR"
fi

# Team SSH pubkey (PasswordAuthentication no on sshd); private key stays on host only.
AUTH_OVERLAY="$DOCKER_ROOT/overlay/board/rockchip/common/rootfs-overlay/root/.ssh/authorized_keys"
if [ -f "$AUTH_OVERLAY" ]; then
	mkdir -p "$TARGET_DIR/root/.ssh"
	cp -f "$AUTH_OVERLAY" "$TARGET_DIR/root/.ssh/authorized_keys"
	chmod 700 "$TARGET_DIR/root/.ssh"
	chmod 600 "$TARGET_DIR/root/.ssh/authorized_keys"
fi

# Buildroot sshd_config may omit Include for sshd_config.d; enforce drop-in load.
# OpenSSH first-match wins: Include MUST be at the top so 50-ssh-auth.conf overrides
# stock PermitRootLogin yes (append-at-end left drop-ins ineffective; Lynis sshd -T saw YES).
SSHD_CFG="$TARGET_DIR/etc/ssh/sshd_config"
if [ -f "$SSHD_CFG" ]; then
	if grep -qE '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/\*\.conf' "$SSHD_CFG"; then
		sed -i '/^[[:space:]]*Include[[:space:]]*\/etc\/ssh\/sshd_config\.d\/\*\.conf/d' "$SSHD_CFG"
	fi
	{
		echo '# lws-hmi: team SSH auth drop-ins (first-match; must precede stock defaults)'
		echo 'Include /etc/ssh/sshd_config.d/*.conf'
		echo
		cat "$SSHD_CFG"
	} >"$SSHD_CFG.new"
	mv "$SSHD_CFG.new" "$SSHD_CFG"
	# Belt-and-suspenders if a later Match/copy reintroduces stock yes.
	sed -i 's/^PermitRootLogin[[:space:]]\{1,\}yes$/PermitRootLogin prohibit-password/' "$SSHD_CFG"
fi

STRIP_FSTAB="$(dirname "$0")/strip-fstab.sh"
if [ -f "$STRIP_FSTAB" ]; then
	bash "$STRIP_FSTAB" "$TARGET_DIR"
fi

sh "$(dirname "$0")/install-systemctl-wrapper.sh" "$TARGET_DIR" post-fakeroot
