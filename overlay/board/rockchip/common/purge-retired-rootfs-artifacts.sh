#!/bin/sh
# Remove pre-rename rootfs artifacts that Buildroot incremental target/ keeps
# even after overlay rsync --delete (units/profile drop-ins under etc/systemd).
set -eu

TARGET_DIR="${1:?TARGET_DIR required}"
SYSTEMD_DIR="$TARGET_DIR/etc/systemd/system"

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

# Renamed functional units (fix-hmi-system-naming).
for unit in \
	lws-hmi-ab-boot-confirm.service \
	lws-hmi-eth0.service \
	lws-hmi-performance.service \
	lws-hmi-serial-stty.service \
	lws-hmi-pwrkey-poweroff.service \
	lws-hmi-usb-otg-role.service \
	lws-hmi-usb-otg-role-boot.service \
	lws-hmi-wpa.service \
	lws-hmi-wlan0-dhcp.service \
	lws-hmi-lan-ssh.service \
	lws-hmi-settings-restore.service \
	lws-hmi-usb-plug-ssh.service \
	lws-hmi-debug-boot.service \
	lws-hmi-pre-poweroff.service \
	lws-hmi-boot-kpi.service; do
	disable_unit "$unit"
done

rm -f \
	"$SYSTEMD_DIR/lws-hmi-ab-boot-confirm.service" \
	"$SYSTEMD_DIR/lws-hmi-eth0.service" \
	"$SYSTEMD_DIR/lws-hmi-performance.service" \
	"$SYSTEMD_DIR/lws-hmi-serial-stty.service" \
	"$SYSTEMD_DIR/lws-hmi-pwrkey-poweroff.service" \
	"$SYSTEMD_DIR/lws-hmi-usb-otg-role.service" \
	"$SYSTEMD_DIR/lws-hmi-usb-otg-role-boot.service" \
	"$SYSTEMD_DIR/lws-hmi-wpa.service" \
	"$SYSTEMD_DIR/lws-hmi-wlan0-dhcp.service" \
	"$SYSTEMD_DIR/lws-hmi-lan-ssh.service" \
	"$SYSTEMD_DIR/lws-hmi-settings-restore.service" \
	"$SYSTEMD_DIR/lws-hmi-usb-plug-ssh.service" \
	"$SYSTEMD_DIR/lws-hmi-debug-boot.service" \
	"$SYSTEMD_DIR/lws-hmi-pre-poweroff.service" \
	"$SYSTEMD_DIR/lws-hmi-boot-kpi.service" \
	"$TARGET_DIR/etc/profile.d/lws-hmi-serial-stty.sh" \
	"$TARGET_DIR/etc/ssh/sshd_config.d/50-lws-hmi-usb-plug-ssh.conf" \
	"$SYSTEMD_DIR/systemd-poweroff.service.d/50-lws-hmi-pre-poweroff.conf" \
	"$SYSTEMD_DIR/systemd-halt.service.d/50-lws-hmi-pre-poweroff.conf" \
	"$SYSTEMD_DIR/systemd-reboot.service.d/50-lws-hmi-pre-poweroff.conf"

rmdir \
	"$SYSTEMD_DIR/systemd-poweroff.service.d" \
	"$SYSTEMD_DIR/systemd-halt.service.d" \
	"$SYSTEMD_DIR/systemd-reboot.service.d" \
	2>/dev/null || true

# Renamed etc drop-ins / presets (Buildroot incremental keeps old basenames).
rm -rf "$TARGET_DIR/etc/lws-hmi"
rm -f \
	"$TARGET_DIR/etc/issue.d/00-lws-hmi-terminal-resize.issue" \
	"$TARGET_DIR/etc/systemd/network/10-lws-hmi-gmac.link" \
	"$TARGET_DIR/etc/systemd/system/bluetooth.service.d/lws-hmi.conf" \
	"$TARGET_DIR/etc/systemd/journald.conf.d/00-lws-hmi-volatile.conf" \
	"$TARGET_DIR/etc/systemd/system-preset/99-lws-hmi.preset" \
	"$TARGET_DIR/etc/ssh/sshd_config.d/50-lws-hmi-ssh-auth.conf" \
	"$TARGET_DIR/etc/udev/rules.d/99-lws-hmi-usb-plug-ssh.rules"

rm -rf "$TARGET_DIR/usr/lib/lws-hmi" "$TARGET_DIR/var/lib/lws-hmi"

# W2: no rootfs OEM migration fallback (compose fails hard without /oem).
# Buildroot incremental target/ keeps this tree after overlay rsync --delete.
rm -rf "$TARGET_DIR/usr/share/hmi/oem-fallback"

# In-HAL HOGP/evdev heal (retired board service + helpers).
disable_unit "bt-hid-heal.service"
rm -f \
	"$SYSTEMD_DIR/bt-hid-heal.service" \
	"$TARGET_DIR/usr/lib/systemd/system/bt-hid-heal.service" \
	"$TARGET_DIR/usr/libexec/bluetooth/bt-hid-heal.sh" \
	"$TARGET_DIR/usr/libexec/bluetooth/bt-hid-heal-loop.sh"
rm -rf "$TARGET_DIR/run/bt-hid" "$TARGET_DIR/var/run/bt-hid"

# H1 (bluez-security-upgrade): OBEX/PBAP unused — Buildroot incremental target/
# keeps obexd + user units after BR2_PACKAGE_BLUEZ5_UTILS_OBEX is unset.
disable_unit "obex.service"
rm -f \
	"$TARGET_DIR/usr/libexec/bluetooth/obexd" \
	"$TARGET_DIR/usr/lib/systemd/user/obex.service" \
	"$TARGET_DIR/usr/lib/systemd/user/dbus-org.bluez.obex.service" \
	"$TARGET_DIR/usr/share/dbus-1/services/org.bluez.obex.service" \
	"$TARGET_DIR/etc/dbus-1/services/org.bluez.obex.service"

# MediaMTX moved to App (/opt/hmi/bin via cyber_pm). Incremental target/ keeps
# former overlay binary/unit/helper after rsync --delete of overlay sources.
disable_unit "mediamtx.service"
rm -f \
	"$SYSTEMD_DIR/mediamtx.service" \
	"$TARGET_DIR/usr/lib/systemd/system/mediamtx.service" \
	"$TARGET_DIR/usr/bin/mediamtx" \
	"$TARGET_DIR/usr/libexec/hmi/render-mediamtx-config.sh"
rm -rf "$TARGET_DIR/etc/mediamtx"

# HMI app OTA: install+restart is App-owned (OtaExtract + tree install +
# systemd-run systemctl restart). Incremental target/ keeps retired shell helpers.
rm -f \
	"$TARGET_DIR/usr/libexec/hmi/push-app-apply-and-restart.sh" \
	"$TARGET_DIR/usr/libexec/hmi/upgrade-app-apply-and-restart.sh"

# Retired snd-aloop record tap: overlay rsync --delete does not clear
# Buildroot incremental target/ (broken asound.conf made ALSA unusable).
rm -f \
	"$TARGET_DIR/etc/asound.conf" \
	"$TARGET_DIR/usr/libexec/hmi/capture-audio-loopback.sh" \
	"$TARGET_DIR/etc/modules-load.d/snd-aloop.conf" \
	"$TARGET_DIR/usr/bin/alsaloop" \
	"$TARGET_DIR/usr/lib/gstreamer-1.0/libgstvoaacenc.so" \
	"$TARGET_DIR/usr/lib/libvo-aacenc.so" \
	"$TARGET_DIR/usr/lib/libvo-aacenc.so.0" \
	"$TARGET_DIR/usr/lib/libvo-aacenc.so.0.0.4"
rm -rf "$TARGET_DIR/etc/systemd/system/hmi-audio-loopback.service" \
	"$TARGET_DIR/usr/lib/systemd/system/hmi-audio-loopback.service"
disable_unit "hmi-audio-loopback.service"

# Innohi display daemons retired (DTS-only panel). Old unit names from ParamUpdate era.
disable_unit "mainserver.service"
disable_unit "param-update.service"
disable_unit "display-init.service"
rm -f \
	"$SYSTEMD_DIR/mainserver.service" \
	"$SYSTEMD_DIR/param-update.service" \
	"$SYSTEMD_DIR/display-init.service" \
	"$TARGET_DIR/usr/bin/MainServer" \
	"$TARGET_DIR/usr/bin/ParamUpdate" \
	"$TARGET_DIR/usr/bin/MountAll" \
	"$TARGET_DIR/system/bin/MainServer" \
	"$TARGET_DIR/system/bin/ParamUpdate" \
	"$TARGET_DIR/system/bin/MountAll"

# ParamUpdate LCD tables retired (panel timing is kernel DT).
rm -f \
	"$TARGET_DIR/system/etc/960_lcd_param_rk356x.txt" \
	"$TARGET_DIR/system/etc/lcd_mipi_param.txt" \
	"$TARGET_DIR/system/etc/LCD_PARAM_RK356X_V11_0.txt"
echo "post-build: purged /system/etc LCD param files (if leftover)"

# libexec-board: helpers moved out of /usr/libexec/hmi/. Buildroot overlay into
# incremental target/ has no --delete for moved files — purge stale copies here.
rm -f \
	"$TARGET_DIR/usr/libexec/hmi/read-device-serial.sh" \
	"$TARGET_DIR/usr/libexec/hmi/read-product-identity.sh" \
	"$TARGET_DIR/usr/libexec/hmi/write-product-identity.sh" \
	"$TARGET_DIR/usr/libexec/hmi/vendor-storage-ids.txt" \
	"$TARGET_DIR/usr/libexec/hmi/secrets-seal" \
	"$TARGET_DIR/usr/libexec/hmi/secrets-seal-ca" \
	"$TARGET_DIR/usr/libexec/hmi/paths.sh" \
	"$TARGET_DIR/usr/libexec/hmi/lws-hostname.sh" \
	"$TARGET_DIR/usr/libexec/hmi/device-mdns-advertise.sh" \
	"$TARGET_DIR/usr/libexec/hmi/serial-console-stty.sh" \
	"$TARGET_DIR/usr/libexec/hmi/reboot-loader" \
	"$TARGET_DIR/usr/libexec/hmi/boot-verify.sh" \
	"$TARGET_DIR/usr/libexec/hmi/env-verify.sh" \
	"$TARGET_DIR/usr/libexec/hmi/usb-otg-mode.sh" \
	"$TARGET_DIR/usr/libexec/hmi/usb-gadget-usb-state.sh" \
	"$TARGET_DIR/usr/libexec/hmi/usb-plug-ssh-start.sh" \
	"$TARGET_DIR/usr/libexec/hmi/usb-plug-ssh-stop.sh" \
	"$TARGET_DIR/usr/libexec/hmi/usb-plug-ssh-recover.sh" \
	"$TARGET_DIR/usr/libexec/hmi/usb-plug-ssh-diag.sh" \
	"$TARGET_DIR/usr/libexec/hmi/usb-plug-ssh-vbus-check.sh" \
	"$TARGET_DIR/usr/libexec/hmi/usb-mtp-start.sh" \
	"$TARGET_DIR/usr/libexec/hmi/usb-mtp-stop.sh" \
	"$TARGET_DIR/usr/libexec/hmi/ab-slot-lib.sh" \
	"$TARGET_DIR/usr/libexec/hmi/ab-upgrade-apply.sh" \
	"$TARGET_DIR/usr/libexec/hmi/ab-upgrade-stream.sh" \
	"$TARGET_DIR/usr/libexec/hmi/ab-boot-confirm.sh" \
	"$TARGET_DIR/usr/libexec/ab/ab-upgrade-apply.sh" \
	"$TARGET_DIR/usr/libexec/ab/ab-upgrade-stream.sh" \
	"$TARGET_DIR/usr/libexec/ab/ab-ota-verify.sh" \
	"$TARGET_DIR/usr/libexec/hmi/oem-compose.sh" \
	"$TARGET_DIR/usr/libexec/hmi/ynh960-display-init.sh" \
	"$TARGET_DIR/usr/libexec/display/ynh960-display-init.sh" \
	"$TARGET_DIR/usr/libexec/display/display-init.sh" \
	"$TARGET_DIR/usr/libexec/hmi/weston-hmi-config.sh" \
	"$TARGET_DIR/usr/libexec/hmi/change-orientation.sh" \
	"$TARGET_DIR/usr/libexec/hmi/apply-mouse-settings.sh" \
	"$TARGET_DIR/usr/libexec/hmi/set-performance-mode.sh" \
	"$TARGET_DIR/usr/libexec/hmi/bind-prefs.sh" \
	"$TARGET_DIR/usr/libexec/display/set-performance-mode.sh" \
	"$TARGET_DIR/usr/libexec/display/bind-prefs.sh" \
	"$TARGET_DIR/usr/libexec/hmi/pre-poweroff.sh" \
	"$TARGET_DIR/usr/libexec/hmi/shutdown.sh" \
	"$TARGET_DIR/usr/libexec/hmi/pwrkey-poweroff.sh" \
	"$TARGET_DIR/usr/libexec/hmi/systemctl-poweroff-wrapper.sh" \
	"$TARGET_DIR/usr/libexec/hmi/enable-ssh-debug.sh" \
	"$TARGET_DIR/usr/libexec/hmi/disable-ssh-debug.sh" \
	"$TARGET_DIR/usr/libexec/hmi/lan-ssh-run.sh" \
	"$TARGET_DIR/usr/libexec/hmi/ensure-sshd-hostkeys.sh"
echo "post-build: purged moved libexec helpers from usr/libexec/hmi (if leftover)"

# Wi-Fi/BT kitchen-sink firmware + Broadcom modules belong to OEM radio pack /
# unused chip paths — purge incremental leftovers from older post-wifibt dumps.
_fw_dirs="
	$TARGET_DIR/usr/lib/firmware
	$TARGET_DIR/lib/firmware
	$TARGET_DIR/vendor/etc/firmware
	$TARGET_DIR/system/etc/firmware
"
for _d in $_fw_dirs; do
	[ -d "$_d" ] || continue
	# Resolve symlink targets once (vendor↔lib hardlink/symlink trees).
	_real="$(readlink -f "$_d" 2>/dev/null || echo "$_d")"
	[ -d "$_real" ] || continue
	# Multi-vendor Rockchip/Innohi dumps (Broadcom/Cypress/RK/AIC/Realtek/…).
	# Product combo blobs live in OEM radio/; keep non-radio firmware elsewhere.
	find "$_real" -maxdepth 1 -type f \( \
		-name 'fw_*' -o \
		-name 'fmacfw*' -o \
		-name 'lmacfw*' -o \
		-name 'aic_*' -o \
		-name 'rtl*' -o \
		-name '*.hcd' -o \
		-name 'nvram*' -o \
		-name 'clm_*' -o \
		-name 'BCM*' -o \
		-name 'brcm*' -o \
		-name 'cyfmac*' -o \
		-name 'RT2870*' -o \
		-name 'wifi_efuse*' -o \
		-name 'ssv6051*' -o \
		-name 'AP6*' -o \
		-name 'SYN*' -o \
		-name 'otp.bin*' -o \
		-name 'BT_Firmware.mk' -o \
		-name 'config.txt' -o \
		-name 'fw_info.txt' -o \
		-name 'readme.txt' \
		\) -delete 2>/dev/null || true
	rm -rf "$_real/rtlbt" "$_real/brcm" 2>/dev/null || true
done
# Broadcom out-of-tree modules not selected for this product line.
for _ko_dir in \
	"$TARGET_DIR/vendor/lib/modules" \
	"$TARGET_DIR/system/lib/modules" \
	"$TARGET_DIR/lib/modules"; do
	[ -d "$_ko_dir" ] || continue
	find "$_ko_dir" -maxdepth 3 -type f -name 'bcmdhd*.ko' -delete 2>/dev/null || true
done
echo "post-build: purged Wi-Fi/BT kitchen-sink firmware + bcmdhd*.ko (if leftover)"

# rk_wifi_init retired — wifibt-bringup uses manual aic8800 insmod.
rm -f "$TARGET_DIR/usr/bin/rk_wifi_init"
echo "post-build: purged rk_wifi_init (if leftover)"
