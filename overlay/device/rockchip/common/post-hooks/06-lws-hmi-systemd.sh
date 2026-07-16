#!/bin/bash -e

# Plan A: enable hmi.service only; disable non-critical units at image build time.
# Note: SDK 07-log-guardian.sh runs after this hook and re-enables log-guardian;
# 08-lws-hmi-systemd-finalize.sh undoes that for staging target/.

source "${RK_POST_HELPER:-$(dirname "$(realpath "$0")")/post-helper}"

[ "$POST_OS" = buildroot ] || exit 0

WANTS="$TARGET_DIR/etc/systemd/system/multi-user.target.wants"
SYSINIT_WANTS="$TARGET_DIR/etc/systemd/system/sysinit.target.wants"
SYSTEMD_DIR="$TARGET_DIR/etc/systemd/system"
mkdir -p "$WANTS" "$SYSINIT_WANTS"

# Units that must not auto-start at boot (§3.6.0 / §6.4). Include sshd.socket — OpenSSH
# often enables socket activation instead of sshd.service.
DISABLE_AT_BOOT=(
	input-event-daemon.service
	lws-hmi-debug-boot.service
	mediamtx.service
	sshd.service
	sshd.socket
	lws-hmi-lan-ssh.service
	lws-hmi-wpa.service
	lws-hmi-wlan0-dhcp.service
	lws-hmi-eth0.service
	bluetooth.service
	wifibt-init.service
	wpa_supplicant.service
	network.service
	dhcpcd.service
	log-guardian.service
)

link_unit() {
	local unit="$1"
	local path="/etc/systemd/system/$unit"
	ln -sf "$path" "$WANTS/$unit"
}

disable_boot_unit() {
	local unit="$1"
	local wants_dir link
	for wants_dir in "$SYSTEMD_DIR"/*.wants \
		"$TARGET_DIR/usr/lib/systemd/system"/*.wants \
		"$TARGET_DIR/lib/systemd/system"/*.wants; do
		[ -d "$wants_dir" ] || continue
		link="$wants_dir/$unit"
		if [ -e "$link" ] || [ -L "$link" ]; then
			rm -f "$link"
			echo "lws-hmi-systemd: removed ${link#$TARGET_DIR/}"
		fi
	done
}

# KPI path: display init early; flutter-pi after local-fs.
if [ -f "$TARGET_DIR/etc/systemd/system/param-update.service" ]; then
	ln -sf "/etc/systemd/system/param-update.service" \
		"$SYSINIT_WANTS/param-update.service"
	echo "lws-hmi-systemd: enabled param-update.service (sysinit.target)"
fi

if [ -f "$TARGET_DIR/etc/systemd/system/mainserver.service" ]; then
	link_unit mainserver.service
	echo "lws-hmi-systemd: enabled mainserver.service"
fi

if [ -f "$TARGET_DIR/etc/systemd/system/lws-hmi-performance.service" ]; then
	link_unit lws-hmi-performance.service
	echo "lws-hmi-systemd: enabled lws-hmi-performance.service"
fi

if [ -f "$TARGET_DIR/etc/systemd/system/lws-hmi-serial-stty.service" ]; then
	link_unit lws-hmi-serial-stty.service
	echo "lws-hmi-systemd: enabled lws-hmi-serial-stty.service"
fi

if [ -f "$TARGET_DIR/etc/systemd/system/lws-hmi-pwrkey-poweroff.service" ]; then
	link_unit lws-hmi-pwrkey-poweroff.service
	echo "lws-hmi-systemd: enabled lws-hmi-pwrkey-poweroff.service"
fi

if [ -f "$TARGET_DIR/etc/systemd/system/hmi.service" ]; then
	link_unit hmi.service
	echo "lws-hmi-systemd: enabled hmi.service"
fi

if [ -f "$TARGET_DIR/etc/systemd/system/lws-hmi-settings-restore.service" ]; then
	link_unit lws-hmi-settings-restore.service
	echo "lws-hmi-systemd: enabled lws-hmi-settings-restore.service"
fi

if [ -f "$TARGET_DIR/etc/systemd/system/lws-hmi-ab-boot-confirm.service" ]; then
	link_unit lws-hmi-ab-boot-confirm.service
	echo "lws-hmi-systemd: enabled lws-hmi-ab-boot-confirm.service"
fi

if [ -f "$TARGET_DIR/etc/systemd/system/lws-hmi-usb-otg-role-boot.service" ]; then
	link_unit lws-hmi-usb-otg-role-boot.service
	echo "lws-hmi-systemd: enabled lws-hmi-usb-otg-role-boot.service"
fi

# Do not block boot KPI; start after home or from App (§6.4).
for unit in "${DISABLE_AT_BOOT[@]}"; do
	if [ -f "$TARGET_DIR/etc/systemd/system/$unit" ] || \
		[ -f "$TARGET_DIR/lib/systemd/system/$unit" ] || \
		[ -f "$TARGET_DIR/usr/lib/systemd/system/$unit" ]; then
		disable_boot_unit "$unit"
	fi
done

# Retired single-image debug path — remove if stale overlay sync left files on disk.
rm -f \
	"$TARGET_DIR/etc/systemd/system/lws-hmi-debug-boot.service" \
	"$TARGET_DIR/etc/systemd/system/lws-hmi-pre-poweroff.service" \
	"$TARGET_DIR/usr/lib/lws-hmi/debug-boot.sh" \
	"$TARGET_DIR/usr/lib/lws-hmi/stop-hmi.sh" \
	"$TARGET_DIR/usr/lib/lws-hmi/push-app-apply-and-reboot.sh" \
	"$TARGET_DIR/etc/systemd/system/systemd-poweroff.service.d/50-lws-hmi-pre-poweroff.conf" \
	"$TARGET_DIR/etc/systemd/system/systemd-halt.service.d/50-lws-hmi-pre-poweroff.conf" \
	"$TARGET_DIR/etc/systemd/system/systemd-reboot.service.d/50-lws-hmi-pre-poweroff.conf"
rmdir \
	"$TARGET_DIR/etc/systemd/system/systemd-poweroff.service.d" \
	"$TARGET_DIR/etc/systemd/system/systemd-halt.service.d" \
	"$TARGET_DIR/etc/systemd/system/systemd-reboot.service.d" \
	2>/dev/null || true
disable_boot_unit lws-hmi-debug-boot.service
disable_boot_unit lws-hmi-pre-poweroff.service

# Plan A: no kernel cmdline ip= and no networkd — mask noisy generator unit.
if [ -d "$SYSTEMD_DIR" ]; then
	ln -sf /dev/null "$SYSTEMD_DIR/systemd-network-generator.service"
	echo "lws-hmi-systemd: masked systemd-network-generator.service"
fi

# Install usr/lib/lws-hmi/*.sh from SDK buildroot board overlay (synced by apply-overlay).
# Do not rely on LWS_HMI_ROOT — Rockchip post-hooks may not inherit it from docker-run.
install_lws_hmi_helper_scripts() {
	local sdk_dir overlay_scripts script
	sdk_dir="${LWS_HMI_SDK_DIR:-${RK_SDK_DIR:-}}"
	if [ -z "$sdk_dir" ]; then
		sdk_dir="$(cd "$(dirname "$TARGET_DIR")/../../../.." && pwd)"
	fi
	overlay_scripts="$sdk_dir/buildroot/board/rockchip/rk3566_rk3568/lws-hmi-fs-overlay/usr/lib/lws-hmi"
	if [ ! -d "$overlay_scripts" ]; then
		echo "lws-hmi-systemd: skip helper scripts (missing $overlay_scripts — run make apply-overlay)"
		return 0
	fi
	install -d "$TARGET_DIR/usr/lib/lws-hmi"
	for script in "$overlay_scripts"/*.sh; do
		[ -f "$script" ] || continue
		install -m 0755 "$script" "$TARGET_DIR/usr/lib/lws-hmi/$(basename "$script")"
		echo "lws-hmi-systemd: installed /usr/lib/lws-hmi/$(basename "$script")"
	done
}

wrap_systemctl_for_poweroff() {
	local ctl="$TARGET_DIR/usr/bin/systemctl"
	local real="$TARGET_DIR/usr/bin/systemctl.real"
	local wrapper="$TARGET_DIR/usr/lib/lws-hmi/systemctl-poweroff-wrapper.sh"

	[ -f "$wrapper" ] || return 0
	if [ -e "$real" ]; then
		echo "lws-hmi-systemd: systemctl wrapper already installed"
		return 0
	fi
	if [ ! -e "$ctl" ]; then
		echo "lws-hmi-systemd: skip systemctl wrapper (missing $ctl)"
		return 0
	fi
	mv "$ctl" "$real"
	ln -sf /usr/lib/lws-hmi/systemctl-poweroff-wrapper.sh "$ctl"
	echo "lws-hmi-systemd: wrapped /usr/bin/systemctl for graceful poweroff"
}
install_lws_hmi_helper_scripts
wrap_systemctl_for_poweroff

# Prebuilt flutter-engine: refresh /usr/lib on target/ (app bundle has no engine copy).
sync_flutter_engine_prebuilt() {
	local script sdk_dir
	sdk_dir="${LWS_HMI_SDK_DIR:-${RK_SDK_DIR:-}}"
	if [ -z "$sdk_dir" ]; then
		sdk_dir="$(cd "$(dirname "$TARGET_DIR")/../../../.." && pwd)"
	fi
	script="$sdk_dir/buildroot/board/rockchip/rk3566_rk3568/lws-hmi-sync-flutter-engine.sh"
	if [ -f "$script" ]; then
		sh "$script" "$TARGET_DIR"
	else
		echo "lws-hmi-systemd: skip flutter engine sync (missing $script — run make apply-overlay)"
	fi
}
sync_flutter_engine_prebuilt

# BlueZ 5.77 + systemd: daemon lives in libexec; compat symlink for scripts using /usr/sbin.
if [ -x "$TARGET_DIR/usr/libexec/bluetooth/bluetoothd" ] && \
	[ ! -e "$TARGET_DIR/usr/sbin/bluetoothd" ]; then
	mkdir -p "$TARGET_DIR/usr/sbin"
	ln -sf ../libexec/bluetooth/bluetoothd "$TARGET_DIR/usr/sbin/bluetoothd"
	echo "lws-hmi-systemd: symlink /usr/sbin/bluetoothd → libexec"
fi

# A-6: noatime on ext4 mounts (root remount + oem/userdata via systemd-fstab-generator).
FSTAB="$TARGET_DIR/etc/fstab"
if [ -f "$FSTAB" ] && ! grep -q 'noatime' "$FSTAB"; then
	sed -i \
		-e 's|\(/ ext4 \)rw |\1rw,noatime |' \
		-e 's|\( ext4 \)defaults |\1defaults,noatime |' \
		"$FSTAB"
	echo "lws-hmi-systemd: patched $FSTAB (noatime)"
fi

# Extra eMMC parts: stripped after 30-fstab.sh by 31-lws-hmi-strip-fstab.sh (and post-build/fakeroot).
