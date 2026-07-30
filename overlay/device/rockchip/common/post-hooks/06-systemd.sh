#!/bin/bash -e

# Plan A: enable hmi.service only; disable non-critical units at image build time.
# Note: SDK 07-log-guardian.sh runs after this hook and re-enables log-guardian;
# 08-systemd-finalize.sh undoes that for staging target/.

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
	lws-hmi-ab-boot-confirm.service
	lws-hmi-performance.service
	lws-hmi-pwrkey-poweroff.service
	lws-hmi-serial-stty.service
	lws-hmi-usb-otg-role-boot.service
	sshd.service
	sshd.socket
	ssh-debug-lan.service
	wlan-wpa.service
	wlan-dhcp.service
	eth0-network.service
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
			echo "post-systemd: removed ${link#$TARGET_DIR/}"
		fi
	done
}

# KPI path: display init early; HMI after local-fs.
if [ -f "$TARGET_DIR/etc/systemd/system/param-update.service" ]; then
	ln -sf "/etc/systemd/system/param-update.service" \
		"$SYSINIT_WANTS/param-update.service"
	echo "post-systemd: enabled param-update.service (sysinit.target)"
fi

if [ -f "$TARGET_DIR/etc/systemd/system/mainserver.service" ]; then
	link_unit mainserver.service
	echo "post-systemd: enabled mainserver.service"
fi

if [ -f "$TARGET_DIR/etc/systemd/system/cpu-performance.service" ]; then
	link_unit cpu-performance.service
	echo "post-systemd: enabled cpu-performance.service"
fi

if [ -f "$TARGET_DIR/etc/systemd/system/serial-stty.service" ]; then
	link_unit serial-stty.service
	echo "post-systemd: enabled serial-stty.service"
fi

if [ -f "$TARGET_DIR/etc/systemd/system/pwrkey-poweroff.service" ]; then
	link_unit pwrkey-poweroff.service
	echo "post-systemd: enabled pwrkey-poweroff.service"
fi

if [ -f "$TARGET_DIR/etc/systemd/system/oem-compose.service" ]; then
	link_unit oem-compose.service
	echo "post-systemd: enabled oem-compose.service"
fi

if [ -f "$TARGET_DIR/etc/systemd/system/hmi.service" ]; then
	link_unit hmi.service
	echo "post-systemd: enabled hmi.service"
fi

if [ -f "$TARGET_DIR/etc/systemd/system/ab-boot-confirm.service" ]; then
	link_unit ab-boot-confirm.service
	echo "post-systemd: enabled ab-boot-confirm.service"
fi

if [ -f "$TARGET_DIR/etc/systemd/system/usb-otg-role-boot.service" ]; then
	link_unit usb-otg-role-boot.service
	echo "post-systemd: enabled usb-otg-role-boot.service"
fi

# Do not block boot KPI; start after home or from App (§6.4).
for unit in "${DISABLE_AT_BOOT[@]}"; do
	if [ -f "$TARGET_DIR/etc/systemd/system/$unit" ] || \
		[ -f "$TARGET_DIR/lib/systemd/system/$unit" ] || \
		[ -f "$TARGET_DIR/usr/lib/systemd/system/$unit" ]; then
		disable_boot_unit "$unit"
	fi
done

# Remove pre-rename units/profile (Buildroot overlay never deletes stale etc/ files).
purge_retired_rootfs_artifacts() {
	local sdk_dir purge_script
	sdk_dir="${LWS_HMI_SDK_DIR:-${RK_SDK_DIR:-}}"
	if [ -z "$sdk_dir" ]; then
		sdk_dir="$(cd "$(dirname "$TARGET_DIR")/../../../.." && pwd)"
	fi
	purge_script="$sdk_dir/buildroot/board/rockchip/rk3566_rk3568/purge-retired-rootfs-artifacts.sh"
	if [ -f "$purge_script" ]; then
		sh "$purge_script" "$TARGET_DIR"
		echo "post-systemd: purged retired rootfs artifacts"
	else
		echo "post-systemd: WARN purge script missing ($purge_script — run make apply-overlay)"
	fi
}
purge_retired_rootfs_artifacts

# Retired single-image debug path — purge script covers units; keep script cleanup.
rm -f \
	"$TARGET_DIR/usr/libexec/hmi/debug-boot.sh" \
	"$TARGET_DIR/usr/libexec/hmi/stop-hmi.sh" \
	"$TARGET_DIR/usr/libexec/hmi/push-app-apply-and-reboot.sh"
disable_boot_unit lws-hmi-debug-boot.service
disable_boot_unit lws-hmi-pre-poweroff.service

# Plan A: no kernel cmdline ip= and no networkd — mask noisy generator unit.
if [ -d "$SYSTEMD_DIR" ]; then
	ln -sf /dev/null "$SYSTEMD_DIR/systemd-network-generator.service"
	echo "post-systemd: masked systemd-network-generator.service"
fi

# Mask stock D-Bus-activated `wpa_supplicant -u` (no iface). HMI opens
# fi.w1.wpa_supplicant1 at boot; without a mask that activates the stock unit and
# blocks on-demand wlan-wpa.service (second -u → Failed to initialize).
# Wi‑Fi L2 is only via wlan-wpa.service → run-wpa.sh (-u -i wlan0).
if [ -d "$SYSTEMD_DIR" ]; then
	ln -sf /dev/null "$SYSTEMD_DIR/wpa_supplicant.service"
	echo "post-systemd: masked wpa_supplicant.service (use wlan-wpa.service)"
fi

# D11: purge leftover dhcpcd from older builds (config has it unset; Buildroot
# does not always remove files from target/ when a package is disabled).
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
echo "post-systemd: purged dhcpcd (networkd-only L3)"

# Install helper scripts from SDK buildroot board overlay (synced by apply-overlay).
# Do not rely on LWS_HMI_ROOT — Rockchip post-hooks may not inherit it from docker-run.
install_lws_hmi_helper_scripts() {
	local sdk_dir overlay_scripts script
	sdk_dir="${LWS_HMI_SDK_DIR:-${RK_SDK_DIR:-}}"
	if [ -z "$sdk_dir" ]; then
		sdk_dir="$(cd "$(dirname "$TARGET_DIR")/../../../.." && pwd)"
	fi
	overlay_scripts="$sdk_dir/buildroot/board/rockchip/rk3566_rk3568/rootfs-overlay/usr/libexec/hmi"
	if [ ! -d "$overlay_scripts" ]; then
		echo "post-systemd: skip helper scripts (missing $overlay_scripts — run make apply-overlay)"
		return 0
	fi
	install -d "$TARGET_DIR/usr/libexec/hmi"
	for script in "$overlay_scripts"/*.sh; do
		[ -f "$script" ] || continue
		install -m 0755 "$script" "$TARGET_DIR/usr/libexec/hmi/$(basename "$script")"
		echo "post-systemd: installed /usr/libexec/hmi/$(basename "$script")"
	done
}

install_lws_hmi_helper_scripts
sdk_dir="${LWS_HMI_SDK_DIR:-${RK_SDK_DIR:-}}"
if [ -z "$sdk_dir" ]; then
	sdk_dir="$(cd "$(dirname "$TARGET_DIR")/../../../.." && pwd)"
fi
if [ -f "$sdk_dir/buildroot/board/rockchip/rk3566_rk3568/install-systemctl-wrapper.sh" ]; then
	sh "$sdk_dir/buildroot/board/rockchip/rk3566_rk3568/install-systemctl-wrapper.sh" \
		"$TARGET_DIR" post-systemd
fi

# Prebuilt flutter-engine: refresh /usr/lib on target/ (app bundle has no engine copy).
sync_flutter_engine_prebuilt() {
	local script sdk_dir
	sdk_dir="${LWS_HMI_SDK_DIR:-${RK_SDK_DIR:-}}"
	if [ -z "$sdk_dir" ]; then
		sdk_dir="$(cd "$(dirname "$TARGET_DIR")/../../../.." && pwd)"
	fi
	script="$sdk_dir/buildroot/board/rockchip/rk3566_rk3568/sync-flutter-engine.sh"
	if [ -f "$script" ]; then
		sh "$script" "$TARGET_DIR"
	else
		echo "post-systemd: skip flutter engine sync (missing $script — run make apply-overlay)"
	fi
}
sync_flutter_engine_prebuilt

# Same for eLinux client + video plugin (Buildroot stamp may keep an old .so).
sync_flutter_elinux_prebuilt() {
	local script sdk_dir
	sdk_dir="${LWS_HMI_SDK_DIR:-${RK_SDK_DIR:-}}"
	if [ -z "$sdk_dir" ]; then
		sdk_dir="$(cd "$(dirname "$TARGET_DIR")/../../../.." && pwd)"
	fi
	script="$sdk_dir/buildroot/board/rockchip/rk3566_rk3568/sync-flutter-embedded-linux.sh"
	if [ -f "$script" ]; then
		sh "$script" "$TARGET_DIR"
	else
		echo "post-systemd: skip flutter-elinux sync (missing $script — run make apply-overlay)"
	fi
}
sync_flutter_elinux_prebuilt

# BlueZ 5.77 + systemd: daemon lives in libexec; compat symlink for scripts using /usr/sbin.
if [ -x "$TARGET_DIR/usr/libexec/bluetooth/bluetoothd" ] && \
	[ ! -e "$TARGET_DIR/usr/sbin/bluetoothd" ]; then
	mkdir -p "$TARGET_DIR/usr/sbin"
	ln -sf ../libexec/bluetooth/bluetoothd "$TARGET_DIR/usr/sbin/bluetoothd"
	echo "post-systemd: symlink /usr/sbin/bluetoothd → libexec"
fi

# D-Bus activation alias (Alias= only appears after systemctl enable; BT stays boot-deferred).
if [ -f "$TARGET_DIR/usr/lib/systemd/system/bluetooth.service" ]; then
	mkdir -p "$TARGET_DIR/etc/systemd/system"
	if [ ! -e "$TARGET_DIR/etc/systemd/system/dbus-org.bluez.service" ] && \
		[ ! -L "$TARGET_DIR/etc/systemd/system/dbus-org.bluez.service" ]; then
		ln -sfn ../../usr/lib/systemd/system/bluetooth.service \
			"$TARGET_DIR/etc/systemd/system/dbus-org.bluez.service"
		echo "post-systemd: alias dbus-org.bluez.service → bluetooth.service"
	fi
fi

# A-6: noatime on ext4 mounts (root remount + oem/userdata via systemd-fstab-generator).
FSTAB="$TARGET_DIR/etc/fstab"
if [ -f "$FSTAB" ] && ! grep -q 'noatime' "$FSTAB"; then
	sed -i \
		-e 's|\(/ ext4 \)rw |\1rw,noatime |' \
		-e 's|\( ext4 \)defaults |\1defaults,noatime |' \
		"$FSTAB"
	echo "post-systemd: patched $FSTAB (noatime)"
fi

# Extra eMMC parts: stripped after 30-fstab.sh by 31-strip-fstab.sh (and post-build/fakeroot).
