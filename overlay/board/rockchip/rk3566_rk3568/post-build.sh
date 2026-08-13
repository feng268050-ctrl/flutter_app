#!/bin/sh
# Run on Buildroot staging target/ before rootfs images are packed (BR2_ROOTFS_POST_BUILD_SCRIPT).
# sshd is disabled at boot — host keys must be baked in at build time.
set -eu

TARGET_DIR="${1:?TARGET_DIR required}"
DOCKER_ROOT="${DOCKER_ROOT:-/work/lws-hmi}"

PURGE="$(dirname "$0")/purge-retired-rootfs-artifacts.sh"
if [ -f "$PURGE" ]; then
	sh "$PURGE" "$TARGET_DIR"
else
	echo "post-build: purge-retired-rootfs-artifacts.sh missing" >&2
	exit 1
fi

ensure_script="$TARGET_DIR/usr/libexec/ssh/ensure-sshd-hostkeys.sh"
if [ ! -f "$ensure_script" ]; then
	ensure_script="$DOCKER_ROOT/overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/usr/libexec/ssh/ensure-sshd-hostkeys.sh"
fi

if [ ! -f "$ensure_script" ]; then
	echo "post-build: ensure-sshd-hostkeys.sh missing" >&2
	exit 1
fi

sh "$ensure_script" "$TARGET_DIR"

STRIP_FSTAB="$(dirname "$0")/strip-fstab.sh"
if [ -f "$STRIP_FSTAB" ]; then
	bash "$STRIP_FSTAB" "$TARGET_DIR"
fi

SYNC_ENGINE="$(dirname "$0")/sync-flutter-engine.sh"
if [ -f "$SYNC_ENGINE" ]; then
	sh "$SYNC_ENGINE" "$TARGET_DIR"
fi

SYNC_ELINUX="$(dirname "$0")/sync-flutter-embedded-linux.sh"
if [ -f "$SYNC_ELINUX" ]; then
	sh "$SYNC_ELINUX" "$TARGET_DIR"
fi

SYNC_BR_VER="$(dirname "$0")/sync-buildroot-version.sh"
if [ -f "$SYNC_BR_VER" ]; then
	sh "$SYNC_BR_VER" "$TARGET_DIR"
else
	echo "post-build: sync-buildroot-version.sh missing" >&2
	exit 1
fi

# Install operator-facing device commands before rootfs image copies are made.
REBOOT_LOADER="$TARGET_DIR/usr/libexec/board/reboot-loader"
if [ ! -x "$REBOOT_LOADER" ]; then
	echo "post-build: missing $REBOOT_LOADER — run: make build-libexec-binaries && make apply-overlay" >&2
	exit 1
fi

mkdir -p "$TARGET_DIR/usr/bin"
ln -sf /usr/libexec/board/boot-verify.sh "$TARGET_DIR/usr/bin/verify-boot"
ln -sf /usr/libexec/board/env-verify.sh "$TARGET_DIR/usr/bin/verify-env"
ln -sf /usr/libexec/hmi/diagnose-hmi.sh "$TARGET_DIR/usr/bin/diagnose-hmi"
ln -sf /usr/libexec/hmi/os-settings-cli.sh "$TARGET_DIR/usr/bin/os-settings"
ln -sf /usr/libexec/hmi/switch-to-os-settings.sh "$TARGET_DIR/usr/bin/switch-to-os-settings"
ln -sf /usr/libexec/hmi/switch-to-hmi.sh "$TARGET_DIR/usr/bin/switch-to-hmi"
ln -sf /usr/libexec/usb/usb-plug-ssh-diag.sh "$TARGET_DIR/usr/bin/diagnose-usb-ssh"
ln -sf /usr/libexec/board/read-device-serial.sh "$TARGET_DIR/usr/bin/read-serial"
ln -sf /usr/libexec/board/read-product-identity.sh "$TARGET_DIR/usr/bin/read-identity"
ln -sf /usr/libexec/board/write-product-identity.sh "$TARGET_DIR/usr/bin/write-identity"
ln -sf /usr/libexec/board/factory-reset.sh "$TARGET_DIR/usr/bin/factory-reset"
ln -sf /usr/libexec/board/read-cloud-ed25519-sealed.sh "$TARGET_DIR/usr/bin/read-cloud-ed25519-sealed"
ln -sf /usr/libexec/board/write-cloud-ed25519-sealed.sh "$TARGET_DIR/usr/bin/write-cloud-ed25519-sealed"
ln -sf /usr/libexec/board/read-seal-kek-wrapped.sh "$TARGET_DIR/usr/bin/read-seal-kek-wrapped"
ln -sf /usr/libexec/board/write-seal-kek-wrapped.sh "$TARGET_DIR/usr/bin/write-seal-kek-wrapped"
ln -sf /usr/libexec/usb/usb-plug-ssh-start.sh "$TARGET_DIR/usr/bin/start-usb-ssh"
ln -sf /usr/libexec/usb/usb-plug-ssh-stop.sh "$TARGET_DIR/usr/bin/stop-usb-ssh"
ln -sf /usr/libexec/usb/usb-plug-ssh-recover.sh "$TARGET_DIR/usr/bin/recover-usb-ssh"
ln -sf /usr/libexec/board/reboot-loader "$TARGET_DIR/usr/bin/reboot-loader"
ln -sf /usr/libexec/display/change-orientation.sh "$TARGET_DIR/usr/bin/change-orientation"
ln -sf /usr/libexec/display/apply-wallpaper.sh "$TARGET_DIR/usr/bin/apply-wallpaper"
ln -sf /usr/libexec/ssh/enable-ssh-debug.sh "$TARGET_DIR/usr/bin/enable-ssh-debug"
ln -sf /usr/libexec/ssh/disable-ssh-debug.sh "$TARGET_DIR/usr/bin/disable-ssh-debug"
ln -sf /usr/libexec/usb/usb-otg-mode.sh "$TARGET_DIR/usr/bin/usb-otg-mode"
ln -sf /usr/libexec/board/set-performance-mode.sh "$TARGET_DIR/usr/bin/set-performance-mode"
ln -sf /usr/libexec/board/set-performance-mode.sh "$TARGET_DIR/usr/bin/set-power-mode"
# Deprecated iface-named path (half-upgraded boards / old callers).
rm -f \
	"$TARGET_DIR/usr/bin/boot-verify" \
	"$TARGET_DIR/usr/bin/env-verify" \
	"$TARGET_DIR/usr/bin/read-device-serial" \
	"$TARGET_DIR/usr/bin/reboot-rockusb-loader" \
	"$TARGET_DIR/usr/bin/lws-hmi-backlight-apply"

# App bundle must not ship engine/icu (system paths only).
rm -f \
	"$TARGET_DIR/opt/hmi/lib/libflutter_engine.so" \
	"$TARGET_DIR/opt/hmi/data/icudtl.dat"

# Release /opt/hmi is AOT (libapp.so). Buildroot overlay rsync into incremental
# target/ has no --delete, so stale JIT blobs from older packaging can linger.
rm -f \
	"$TARGET_DIR/opt/hmi/data/flutter_assets/kernel_blob.bin" \
	"$TARGET_DIR/opt/hmi/data/flutter_assets/isolate_snapshot_data" \
	"$TARGET_DIR/opt/hmi/data/flutter_assets/vm_snapshot_data"
echo "post-build: purged Flutter JIT orphans under opt/hmi (if leftover)"

# RKNN runtime is system-owned at /usr/lib; do not keep a duplicate under /opt/hmi.
rm -f "$TARGET_DIR"/opt/hmi/lib/librknnrt.so*
echo "post-build: purged opt/hmi librknnrt.so duplicate (if leftover)"

# Covers/AI frame extract uses /usr/libexec/hmi/extract-video-frame (GStreamer).
# Incremental target/ retains App-bundled ffmpeg after bundle cutover — drop it.
rm -f "$TARGET_DIR/opt/hmi/bin/ffmpeg"
echo "post-build: purged opt/hmi/bin/ffmpeg (if leftover)"

# systemd hwdb: ship compiled /usr/lib/udev/hwdb.bin only (~−8 MiB sources).
# Buildroot finalize runs `systemd-hwdb update --usr` *before* this script, and
# `make rootfs-ext2` re-runs finalize (phony). A prior purge that left target
# without *.hwdb causes that update to *delete* hwdb.bin — so re-seed from the
# systemd build tree when needed, rebuild bin, then drop sources again.
_hwdb_d="$TARGET_DIR/usr/lib/udev/hwdb.d"
_hwdb_bin="$TARGET_DIR/usr/lib/udev/hwdb.bin"
_hwdb_src=""
for _d in "$TARGET_DIR"/../build/systemd-[0-9]*/hwdb.d; do
	if [ -d "$_d" ] && ls "$_d"/*.hwdb >/dev/null 2>&1; then
		_hwdb_src="$_d"
		break
	fi
done
_need_hwdb_rebuild=0
if [ ! -s "$_hwdb_bin" ]; then
	_need_hwdb_rebuild=1
fi
if [ "$_need_hwdb_rebuild" = 1 ]; then
	if [ -z "$_hwdb_src" ]; then
		echo "post-build: ERROR missing hwdb.bin and no systemd-*/hwdb.d to rebuild" >&2
		exit 1
	fi
	mkdir -p "$_hwdb_d"
	cp -a "$_hwdb_src"/. "$_hwdb_d"/
	_hwdb_tool="$TARGET_DIR/../host/bin/systemd-hwdb"
	if [ ! -x "$_hwdb_tool" ]; then
		echo "post-build: ERROR missing host systemd-hwdb at $_hwdb_tool" >&2
		exit 1
	fi
	"$_hwdb_tool" update --root "$TARGET_DIR" --strict --usr
	echo "post-build: rebuilt usr/lib/udev/hwdb.bin from $_hwdb_src"
fi
if [ ! -s "$_hwdb_bin" ]; then
	echo "post-build: ERROR usr/lib/udev/hwdb.bin missing after hwdb ensure" >&2
	exit 1
fi
if [ -d "$_hwdb_d" ]; then
	rm -f "$_hwdb_d"/*
fi
if [ -d "$TARGET_DIR/etc/udev/hwdb.d" ]; then
	rm -f "$TARGET_DIR"/etc/udev/hwdb.d/*.hwdb
fi
rm -f "$TARGET_DIR/etc/udev/hwdb.bin"
unset _hwdb_d _hwdb_bin _hwdb_src _hwdb_tool _need_hwdb_rebuild _d
echo "post-build: purged udev hwdb.d sources (kept usr/lib/udev/hwdb.bin)"

# Optional second Flutter app (os_settings): same no-engine / no-JIT rules.
if [[ -d "$TARGET_DIR/opt/os_settings" ]]; then
	rm -f \
		"$TARGET_DIR/opt/os_settings/lib/libflutter_engine.so" \
		"$TARGET_DIR/opt/os_settings/data/icudtl.dat"
	rm -f \
		"$TARGET_DIR/opt/os_settings/data/flutter_assets/kernel_blob.bin" \
		"$TARGET_DIR/opt/os_settings/data/flutter_assets/isolate_snapshot_data" \
		"$TARGET_DIR/opt/os_settings/data/flutter_assets/vm_snapshot_data"
	rm -f "$TARGET_DIR"/opt/os_settings/lib/librknnrt.so*
	echo "post-build: purged Flutter orphans under opt/os_settings (if leftover)"
fi

# Retired Kind C helpers — HAL owns persist/restore for most prefs.
# apply-mouse-settings is kept: Weston needs ini rewrite + active seat restart.
rm -f \
	"$TARGET_DIR/usr/bin/change-backlight" \
	"$TARGET_DIR/usr/bin/change-volume" \
	"$TARGET_DIR/usr/bin/apply-proxy" \
	"$TARGET_DIR/usr/bin/sync-time" \
	"$TARGET_DIR/usr/libexec/hmi/restore-settings.sh" \
	"$TARGET_DIR/usr/libexec/hmi/change-backlight.sh" \
	"$TARGET_DIR/usr/libexec/hmi/change-volume.sh" \
	"$TARGET_DIR/usr/libexec/hmi/time-sync.sh" \
	"$TARGET_DIR/usr/libexec/wpa/wlan0-time-sync.sh" \
	"$TARGET_DIR/usr/libexec/network/apply-proxy.sh" \
	"$TARGET_DIR/etc/systemd/system/settings-restore.service" \
	"$TARGET_DIR/etc/systemd/system/multi-user.target.wants/settings-restore.service"

# Operator symlink for mouse prefs (Weston / eLinux).
if [ -f "$TARGET_DIR/usr/libexec/display/apply-mouse-settings.sh" ]; then
	ln -sf /usr/libexec/display/apply-mouse-settings.sh \
		"$TARGET_DIR/usr/bin/apply-mouse-settings"
fi

# Product image is Weston + flutter-wayland-client only. Purge any leftover
# flutter-pi binary from a previous Buildroot output reuse.
rm -f "$TARGET_DIR/usr/bin/flutter-pi"
echo "post-build: purged flutter-pi (if leftover)"

# P1 forbids Android adbd; package is unset but incremental target/ may keep
# usr/bin/adbd + profile.d from an older lunch / EVB bake.
rm -f \
	"$TARGET_DIR/usr/bin/adbd" \
	"$TARGET_DIR/sbin/adbd" \
	"$TARGET_DIR/system/bin/adbd" \
	"$TARGET_DIR/etc/profile.d/adbd.sh"
echo "post-build: purged adbd (if leftover)"

# Prebuilt avahi-daemon skips Buildroot AVAHI_USERS. Users table should create
# the account; this is an idempotent safety net if mkusers did not run.
if [ -x "$TARGET_DIR/usr/sbin/avahi-daemon" ]; then
	if ! grep -q '^avahi:' "$TARGET_DIR/etc/group" 2>/dev/null; then
		echo 'avahi:x:110:' >> "$TARGET_DIR/etc/group"
		echo "post-build: added group avahi (gid 110)"
	fi
	if ! grep -q '^avahi:' "$TARGET_DIR/etc/passwd" 2>/dev/null; then
		gid="$(awk -F: '$1=="avahi"{print $3; exit}' "$TARGET_DIR/etc/group")"
		echo "avahi:x:104:${gid}:Avahi mDNS daemon:/run/avahi-daemon:/bin/false" \
			>> "$TARGET_DIR/etc/passwd"
		echo "post-build: added user avahi (uid 104)"
	fi
	if [ -f "$TARGET_DIR/etc/shadow" ] && ! grep -q '^avahi:' "$TARGET_DIR/etc/shadow"; then
		echo 'avahi:!:0:0:99999:7:::' >> "$TARGET_DIR/etc/shadow"
	fi
fi

has_weston=0
if [ -x "$TARGET_DIR/usr/bin/weston" ] && \
	[ -x "$TARGET_DIR/usr/bin/flutter-wayland-client" ]; then
	has_weston=1
fi
mkdir -p "$TARGET_DIR/etc/hmi"
if [ "$has_weston" -ne 1 ]; then
	echo "post-build: ERROR weston/flutter-wayland-client missing" >&2
	echo "post-build:   bash scripts/ensure-mali-variant.sh wayland-gbm" >&2
	echo "post-build:   (or: make prepare-rootfs && make build-rootfs)" >&2
	exit 1
fi
# Retired stamps / helpers (Buildroot overlay copy does not delete removed files).
rm -f \
	"$TARGET_DIR/etc/display-stack" \
	"$TARGET_DIR/etc/hmi/display-stack" \
	"$TARGET_DIR/etc/hmi/usb-otg.ini" \
	"$TARGET_DIR/etc/hmi/flutter-engine.version" \
	"$TARGET_DIR/usr/libexec/hmi/ab-upgrade-app-only.sh" \
	"$TARGET_DIR/usr/libexec/hmi/lws-hmi-backlight-apply.sh" \
	"$TARGET_DIR/usr/libexec/hmi/lws-hmi-eth0-apply.sh" \
	"$TARGET_DIR/usr/libexec/hmi/lws-hmi-wpa-run.sh" \
	"$TARGET_DIR/usr/libexec/hmi/lws-hmi-settings-restore.sh" \
	"$TARGET_DIR/usr/libexec/hmi/lws-hmi-prefs-bind.sh"
echo "post-build: weston + flutter-wayland-client OK"

# Baked etc/ must not reference removed monolithic helper/state dirs.
stale_refs=""
if command -v grep >/dev/null 2>&1; then
	stale_refs="$(grep -r '/usr/lib/lws-hmi\|/var/lib/lws-hmi' "$TARGET_DIR/etc" 2>/dev/null || true)"
fi
if [ -n "$stale_refs" ]; then
	echo "post-build: ERROR stale lws-hmi paths still baked under etc/:" >&2
	printf '%s\n' "$stale_refs" >&2
	echo "post-build: run make apply-overlay && make build-rootfs (purge lws-hmi-fs-overlay)" >&2
	exit 1
fi
stale_etc_names=""
if command -v find >/dev/null 2>&1; then
	for f in $(find "$TARGET_DIR/etc" -name '*lws-hmi*' 2>/dev/null); do
		[ -n "$f" ] || continue
		stale_etc_names="${stale_etc_names:+$stale_etc_names }${f#$TARGET_DIR/}"
	done
fi
if [ -n "$stale_etc_names" ]; then
	echo "post-build: ERROR retired *lws-hmi* etc basenames still present:" >&2
	printf '%s\n' "$stale_etc_names" >&2
	exit 1
fi

# Rockchip bluez-alsa.mk uses --enable-debug; configure then links -lSegFault when
# glibc's libSegFault.so is in the sysroot. Buildroot does not install that .so
# on target → bluealsa exits 127 ("cannot open shared object file").
# Copy from staging/sysroot until/unless the package is rebuilt without -lSegFault.
if [ -x "$TARGET_DIR/usr/bin/bluealsa" ]; then
	if [ ! -e "$TARGET_DIR/usr/lib/libSegFault.so" ] && \
		[ ! -e "$TARGET_DIR/lib/libSegFault.so" ]; then
		seg_src=""
		for cand in \
			"${STAGING_DIR:-}/usr/lib/libSegFault.so" \
			"${STAGING_DIR:-}/lib/libSegFault.so" \
			"$(dirname "$TARGET_DIR")/host/aarch64-buildroot-linux-gnu/sysroot/usr/lib/libSegFault.so"
		do
			if [ -f "$cand" ]; then
				seg_src="$cand"
				break
			fi
		done
		if [ -n "$seg_src" ]; then
			mkdir -p "$TARGET_DIR/usr/lib"
			cp -a "$seg_src" "$TARGET_DIR/usr/lib/libSegFault.so"
			echo "post-build: installed usr/lib/libSegFault.so (bluealsa)"
		else
			echo "post-build: WARN libSegFault.so not found — bluealsa may fail" >&2
		fi
	fi
fi

sh "$(dirname "$0")/install-systemctl-wrapper.sh" "$TARGET_DIR" post-build

# Rockchip device/rockchip/common/scripts/post-hostname.sh sets
# HOSTNAME=$RK_CHIP-$POST_OS → rk3566rk3568-buildroot, overwriting BR2.
# Shared product Image is chip-agnostic (P3.2 QEMU + future SoCs).
HOSTNAME_PRODUCT=buildroot
echo "$HOSTNAME_PRODUCT" >"$TARGET_DIR/etc/hostname"
if [ -f "$TARGET_DIR/etc/hosts" ]; then
	sed -i '/^127\.0\.1\.1/d' "$TARGET_DIR/etc/hosts"
fi
echo "127.0.1.1	$HOSTNAME_PRODUCT" >>"$TARGET_DIR/etc/hosts"
echo "post-build: hostname=$HOSTNAME_PRODUCT (override Rockchip \$RK_CHIP-buildroot)"

# Cyber OS identity (must survive BR target-finalize + Rockchip hooks).
if [ ! -f "$TARGET_DIR/etc/os-release" ] || \
	! grep -q '^ID=cyberos$' "$TARGET_DIR/etc/os-release" || \
	! grep -q '^NAME="Cyber OS"$' "$TARGET_DIR/etc/os-release"; then
	echo "post-build: ERROR /etc/os-release must be Cyber OS (overlay etc/os-release)" >&2
	exit 1
fi
echo "post-build: /etc/os-release is Cyber OS"

# P3.2 emulator GLES: do NOT bake Mesa into device rootfs. Host qemu-virgl +
# 9p mount of prebuilt/emulator-swgl (see run-emulator.sh / hmi-launch.sh).
if [ -d "$TARGET_DIR/opt/lws-swgl" ]; then
	rm -rf "$TARGET_DIR/opt/lws-swgl"
	echo "post-build: removed /opt/lws-swgl (use host VirGL + 9p Mesa instead)"
fi
