#!/usr/bin/env bash
# After build-rootfs: confirm overlay files in target/ and Plan A systemd in rootfs.ext2.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${LWS_HMI_SDK_DIR:-$ROOT/linux-sdk}"
SIZE_HELPER="$ROOT/scripts/artifact-size.sh"
source "$ROOT/scripts/prebuilt-common.sh"

if [[ "$(uname -s)" == Darwin && "${1:-}" != "--inside-docker" ]]; then
	exec bash "$ROOT/scripts/docker-run.sh" bash -lc \
		'bash /work/lws-hmi/scripts/verify-rootfs-overlay.sh --inside-docker'
fi

check_systemd_wants() {
	local root="$1"
	local label="$2"
	local wants="$root/etc/systemd/system/multi-user.target.wants"
	local missing=0

	unit_wants_link() {
		# .wants entries use absolute symlinks (/etc/...); do not follow onto host.
		[[ -L "$wants/$1" || -f "$wants/$1" ]]
	}

	echo ""
	echo "--- $label: multi-user.target.wants ---"
	if [[ ! -d "$wants" ]]; then
		echo "FAIL: missing $wants" >&2
		return 1
	fi
	ls -la "$wants" 2>/dev/null || true

	for unit in input-event-daemon.service lws-hmi-debug-boot.service lws-hmi-usb-plug-ssh.service mediamtx.service sshd.service sshd.socket bluetooth.service wifibt-init.service wpa_supplicant.service network.service log-guardian.service; do
		if unit_wants_link "$unit"; then
			echo "FAIL: $unit still enabled in $label" >&2
			missing=1
		else
			echo "OK:  $unit not in $label wants"
		fi
	done

	for unit in hmi.service mainserver.service lws-hmi-performance.service lws-hmi-pwrkey-poweroff.service; do
		if unit_wants_link "$unit"; then
			echo "OK:  $unit enabled in $label"
		else
			echo "FAIL: $unit missing from $label wants" >&2
			missing=1
		fi
	done

	local sysinit_wants="$root/etc/systemd/system/sysinit.target.wants"
	if [[ -d "$sysinit_wants" ]]; then
		for unit in lws-hmi-debug-boot.service wifibt-init.service log-guardian.service usbdevice.service; do
			if [[ -L "$sysinit_wants/$unit" || -f "$sysinit_wants/$unit" ]]; then
				echo "FAIL: $unit still enabled in $label sysinit.target.wants" >&2
				missing=1
			else
				echo "OK:  $unit not in $label sysinit.target.wants"
			fi
		done
	fi

	return "$missing"
}

check_poweroff_hook() {
	local root="$1"
	local label="$2"
	local missing=0

	echo ""
	echo "--- $label: crash-safe poweroff hook ---"
	if [[ -x "$root/usr/lib/lws-hmi/pre-poweroff.sh" && \
		-x "$root/usr/lib/lws-hmi/shutdown.sh" && \
		-x "$root/usr/lib/lws-hmi/systemctl-poweroff-wrapper.sh" ]]; then
		echo "OK:  pre-poweroff/shutdown/systemctl wrapper scripts present in $label"
	else
		echo "FAIL: missing graceful poweroff helper scripts in $label" >&2
		missing=1
	fi

	if [[ -x "$root/usr/bin/systemctl.real" && \
		-L "$root/usr/bin/systemctl" && \
		"$(readlink "$root/usr/bin/systemctl")" = "/usr/lib/lws-hmi/systemctl-poweroff-wrapper.sh" ]]; then
		echo "OK:  /usr/bin/systemctl wrapped via systemctl.real in $label"
	else
		echo "FAIL: /usr/bin/systemctl wrapper not installed in $label" >&2
		missing=1
	fi

	if [[ -f "$root/etc/systemd/system/systemd-poweroff.service.d/50-lws-hmi-pre-poweroff.conf" ]]; then
		echo "FAIL: retired systemd-poweroff drop-in still present in $label" >&2
		missing=1
	else
		echo "OK:  retired systemd-poweroff drop-in absent in $label"
	fi

	if [[ -L "$root/etc/systemd/system/poweroff.target.wants/lws-hmi-pre-poweroff.service" || \
		-f "$root/etc/systemd/system/poweroff.target.wants/lws-hmi-pre-poweroff.service" ]]; then
		echo "FAIL: retired lws-hmi-pre-poweroff.service still linked in $label" >&2
		missing=1
	else
		echo "OK:  retired lws-hmi-pre-poweroff.service not linked in $label"
	fi

	return "$missing"
}

check_rootfs_image() {
	local out_dir="$1"
	local img="$out_dir/images/rootfs.ext2"
	local mnt
	mnt="$(mktemp -d)"

	if [[ ! -r "$img" ]]; then
		echo ""
		echo "WARN: rootfs.ext2 missing — skip flash image systemd check"
		echo "  (run: make build-rootfs to regenerate images/rootfs.ext2)"
		return 0
	fi

	echo ""
	echo "--- rootfs flash image ---"
	bash "$SIZE_HELPER" "$img"

	if ! mount -o loop,ro "$img" "$mnt" 2>/dev/null; then
		echo ""
		echo "FAIL: could not mount $img for verification" >&2
		rmdir "$mnt" 2>/dev/null || true
		return 1
	fi

	check_systemd_wants "$mnt" "rootfs.ext2 (flash image)"
	local rc=$?
	check_poweroff_hook "$mnt" "rootfs.ext2 (flash image)" || rc=1
	if ls "$mnt/etc/ssh"/ssh_host_*_key >/dev/null 2>&1; then
		echo "OK:  ssh host keys present in rootfs.ext2"
	else
		echo "FAIL: missing /etc/ssh/ssh_host_*_key in rootfs.ext2" >&2
		rc=1
	fi
	umount "$mnt"
	rmdir "$mnt"
	return "$rc"
}

run_check() {
	local target="$1"
	local out_dir
	local helper="$target/usr/lib/lws-hmi"
	local missing=0

	out_dir="$(dirname "$target")"
	echo "=== verify-rootfs-overlay ==="
	echo "target: $target"

	if [[ ! -d "$target" ]]; then
		echo "FAIL: staging target missing — run: make build-rootfs" >&2
		echo "  (expected buildroot/output/<RK_BUILDROOT_CFG>/target, e.g. rockchip_rk3566_rk3568_lws_hmi)" >&2
		exit 1
	fi

	echo ""
	echo "--- Buildroot output size ---"
	bash "$SIZE_HELPER" "$target" "$out_dir/images/rootfs.ext2" "$out_dir/images/rootfs.ext4"

	if [[ ! -d "$helper" ]]; then
		echo "FAIL: $helper missing — overlay not applied or wrong Buildroot profile" >&2
		exit 1
	fi

	echo ""
	echo "--- $helper ---"
	ls -la "$helper" || true

	for f in boot-verify.sh env-verify.sh ynh960-display-init.sh set-performance-mode.sh serial-console-stty.sh ensure-sshd-hostkeys.sh usb-plug-ssh-recover.sh pwrkey-poweroff.sh pre-poweroff.sh shutdown.sh systemctl-poweroff-wrapper.sh reboot-loader read-device-serial.sh hmi-stop-and-wait.sh usb-plug-ssh-vbus-check.sh usb-plug-ssh-start.sh usb-plug-ssh-stop.sh push-app-apply-and-restart.sh wifi-stack-up.sh wifi-stack-down.sh wlan0-dhcp.sh wlan0-static.sh wlan0-time-sync.sh bt-stack-up.sh bt-stack-down.sh bt-pair-agent.sh bt-ensure-agent.sh bt-set-alias.sh bt-trust-paired.sh wifibt-bringup.sh; do
		if [[ -x "$helper/$f" ]]; then
			echo "OK:  $f"
		else
			echo "FAIL: $f missing or not executable" >&2
			missing=1
		fi
	done

	echo ""
	echo "--- wifibt prefs under /var/lib/lws-hmi ---"
	for f in wpa_supplicant.conf wlan0-ipv4 http-proxy; do
		if [[ -f "$target/var/lib/lws-hmi/$f" ]]; then
			echo "OK:  var/lib/lws-hmi/$f"
		else
			echo "FAIL: var/lib/lws-hmi/$f missing" >&2
			missing=1
		fi
	done
	if [[ -f "$target/etc/dbus-1/system.d/bluetooth.conf" ]]; then
		echo "OK:  etc/dbus-1/system.d/bluetooth.conf"
	else
		echo "FAIL: etc/dbus-1/system.d/bluetooth.conf missing" >&2
		missing=1
	fi
	if [[ -f "$target/vendor/lib/modules/aic8800_fdrv.ko" ]] || \
		[[ -f "$target/system/lib/modules/aic8800_fdrv.ko" ]] || \
		[[ -f "$target/lib/modules/aic8800_fdrv.ko" ]] || \
		compgen -G "$target/lib/modules/*/aic8800_fdrv.ko" >/dev/null 2>&1 || \
		compgen -G "$target/vendor/lib/modules/**/aic8800_fdrv.ko" >/dev/null 2>&1; then
		echo "OK:  aic8800_fdrv.ko (AIC8800D80)"
	else
		echo "FAIL: aic8800_fdrv.ko missing — enable lws-hmi-ynh960-wifibt.config, rebuild kernel+rootfs" >&2
		missing=1
	fi
	if [[ -x "$target/usr/bin/rk_wifi_init" ]]; then
		echo "OK:  usr/bin/rk_wifi_init"
	else
		echo "WARN: usr/bin/rk_wifi_init missing (optional Innohi helper)" >&2
	fi
	if [[ -s "$target/etc/ssl/certs/ca-certificates.crt" ]]; then
		echo "OK:  etc/ssl/certs/ca-certificates.crt"
	else
		echo "FAIL: etc/ssl/certs/ca-certificates.crt missing — enable BR2_PACKAGE_CA_CERTIFICATES" >&2
		missing=1
	fi

	echo ""
	echo "--- operator commands in /usr/bin ---"
	while read -r cmd implementation; do
		if [[ -L "$target/usr/bin/$cmd" && \
			"$(readlink "$target/usr/bin/$cmd")" == "$implementation" ]]; then
			echo "OK:  usr/bin/$cmd -> $implementation"
		else
			echo "FAIL: invalid or missing usr/bin/$cmd" >&2
			missing=1
		fi
	done <<'EOF'
verify-boot /usr/lib/lws-hmi/boot-verify.sh
verify-env /usr/lib/lws-hmi/env-verify.sh
diagnose-hmi /usr/lib/lws-hmi/diagnose-hmi.sh
diagnose-usb-ssh /usr/lib/lws-hmi/usb-plug-ssh-diag.sh
read-serial /usr/lib/lws-hmi/read-device-serial.sh
start-usb-ssh /usr/lib/lws-hmi/usb-plug-ssh-start.sh
stop-usb-ssh /usr/lib/lws-hmi/usb-plug-ssh-stop.sh
recover-usb-ssh /usr/lib/lws-hmi/usb-plug-ssh-recover.sh
reboot-loader /usr/lib/lws-hmi/reboot-loader
EOF
	for retired in boot-verify env-verify read-device-serial reboot-rockusb-loader; do
		if [[ -e "$target/usr/bin/$retired" || -L "$target/usr/bin/$retired" ]]; then
			echo "FAIL: retired usr/bin/$retired command still present" >&2
			missing=1
		else
			echo "OK:  retired usr/bin/$retired command absent"
		fi
	done
	if [[ -e "$target/usr/lib/lws-hmi/reboot-rockusb-loader" ]]; then
		echo "FAIL: retired usr/lib/lws-hmi/reboot-rockusb-loader still present" >&2
		missing=1
	fi

	if [[ -f "$target/etc/systemd/system/hmi.service" ]]; then
		echo "OK:  hmi.service in target"
	else
		echo "FAIL: hmi.service missing from target/etc/systemd/system" >&2
		missing=1
	fi

	echo ""
	echo "--- Rockchip usbdevice (must not conflict with plug-ssh ECM) ---"
	if [[ -x "$target/usr/bin/usbdevice" ]]; then
		echo "FAIL: usr/bin/usbdevice still present" >&2
		missing=1
	else
		echo "OK:  usr/bin/usbdevice absent"
	fi
	if [[ -L "$target/etc/systemd/system/usbdevice.service" && \
		"$(readlink "$target/etc/systemd/system/usbdevice.service" 2>/dev/null)" == "/dev/null" ]]; then
		echo "OK:  usbdevice.service masked"
	elif [[ ! -e "$target/etc/systemd/system/usbdevice.service" && \
		! -e "$target/usr/lib/systemd/system/usbdevice.service" ]]; then
		echo "OK:  usbdevice.service absent"
	else
		echo "FAIL: usbdevice.service not masked/absent" >&2
		missing=1
	fi

	echo ""
	echo "--- USB plug-ssh debug ---"
	for f in \
		"$target/etc/systemd/system/lws-hmi-usb-plug-ssh.service" \
		"$target/etc/systemd/system/lws-hmi-serial-stty.service" \
		"$target/etc/udev/rules.d/99-lws-hmi-usb-plug-ssh.rules" \
		"$target/etc/ssh/sshd_config.d/50-lws-hmi-usb-plug-ssh.conf" \
		"$target/etc/profile.d/lws-hmi-serial-stty.sh" \
		"$target/etc/issue.d/00-lws-hmi-terminal-resize.issue"; do
		if [[ -e "$f" ]]; then
			echo "OK:  ${f#$target/}"
		else
			echo "FAIL: missing ${f#$target/}" >&2
			missing=1
		fi
	done
	if grep -q 'ListenAddress 192.168.55.1' \
		"$target/etc/ssh/sshd_config.d/50-lws-hmi-usb-plug-ssh.conf" 2>/dev/null; then
		echo "OK:  sshd drop-in ListenAddress 192.168.55.1"
	else
		echo "FAIL: sshd drop-in missing ListenAddress 192.168.55.1" >&2
		missing=1
	fi
	if ls "$target/etc/ssh"/ssh_host_*_key >/dev/null 2>&1; then
		echo "OK:  ssh host keys present in etc/ssh"
	else
		echo "FAIL: missing /etc/ssh/ssh_host_*_key (ensure-sshd-hostkeys / post-fakeroot)" >&2
		missing=1
	fi
	if grep -q 'modprobe g_ether' "$helper/usb-plug-ssh-start.sh" 2>/dev/null && \
		! grep -q '/sys/kernel/config/usb_gadget/lws_hmi' "$helper/usb-plug-ssh-start.sh" 2>/dev/null; then
		echo "OK:  USB plug-ssh uses g_ether without configfs UDC binding"
	else
		echo "FAIL: USB plug-ssh is not the g_ether implementation" >&2
		missing=1
	fi
	if [[ -f "$target/system/lib/modules/g_ether.ko" ]]; then
		echo "OK:  system/lib/modules/g_ether.ko"
	else
		echo "FAIL: g_ether.ko missing from rootfs" >&2
		missing=1
	fi

	echo ""
	echo "--- /etc/fstab (extra parts via ynh960-display-init, not local-fs) ---"
	if [[ -f "$target/etc/fstab" ]]; then
		if grep -qE '[[:space:]]/userdata[[:space:]]' "$target/etc/fstab" || \
			grep -qE '^PARTLABEL=userdata[[:space:]]' "$target/etc/fstab"; then
			echo "FAIL: /etc/fstab must not mount /userdata (ynh960-display-init mounts PARTLABEL=userdata with auto-mkfs)" >&2
			missing=1
		else
			echo "OK:  /userdata not in fstab"
		fi
	else
		echo "WARN: /etc/fstab missing"
	fi

	echo ""
	echo "--- /opt/hmi (Flutter app bundle — no engine) ---"
	for f in \
		"$target/opt/hmi/lib/libapp.so" \
		"$target/opt/hmi/data/flutter_assets/AssetManifest.bin"; do
		if [[ -e "$f" ]]; then
			echo "OK:  ${f#$target/}"
		else
			echo "FAIL: missing ${f#$target/} (run: make build-app && make apply-overlay && make build-rootfs)" >&2
			missing=1
		fi
	done
	if [[ -f "$target/opt/hmi/lib/libflutter_engine.so" ]]; then
		echo "FAIL: opt/hmi/lib/libflutter_engine.so present (engine belongs in /usr/lib only)" >&2
		missing=1
	else
		echo "OK:  opt/hmi/lib/libflutter_engine.so absent (system engine)"
	fi
	if [[ -f "$target/opt/hmi/data/icudtl.dat" ]]; then
		echo "FAIL: opt/hmi/data/icudtl.dat present (use /usr/share/flutter on rootfs)" >&2
		missing=1
	else
		echo "OK:  opt/hmi/data/icudtl.dat absent (system icu)"
	fi
	if [[ -f "$target/usr/lib/libflutter_engine.so" ]]; then
		system_sz="$(stat -c%s "$target/usr/lib/libflutter_engine.so" 2>/dev/null || stat -f%z "$target/usr/lib/libflutter_engine.so")"
		echo "OK:  usr/lib/libflutter_engine.so ($system_sz bytes)"
	else
		echo "FAIL: usr/lib/libflutter_engine.so missing (flutter-engine / post-hook sync)" >&2
		missing=1
	fi

	for f in \
		"$target/etc/systemd/system/lws-hmi-debug-boot.service" \
		"$target/etc/systemd/system/lws-hmi-boot-kpi.service" \
		"$target/usr/lib/lws-hmi/debug-boot.sh" \
		"$target/usr/lib/lws-hmi/boot-kpi-watch.sh" \
		"$target/usr/lib/lws-hmi/configure-camera-eth0.sh" \
		"$target/usr/lib/lws-hmi/enable-ssh-debug.sh"; do
		if [[ -e "$f" ]]; then
			echo "FAIL: retired artifact still in target: $f" >&2
			missing=1
		else
			echo "OK:  $(basename "$f") absent from target"
		fi
	done

	check_systemd_wants "$target" "staging target" || missing=1
	check_poweroff_hook "$target" "staging target" || missing=1

	def="$ROOT/overlay/buildroot/rockchip_rk3566_rk3568_lws_hmi_defconfig"
	gen="$ROOT/overlay/buildroot/.generated/rockchip_rk3566_rk3568_lws_hmi_defconfig"
	[[ -f "$gen" ]] && def="$gen"
	if grep -qF '#include "chips/lws_hmi_bt.config"' "$def" 2>/dev/null; then
		echo ""
		echo "--- BlueZ / wifibt (lws_hmi_bt.config) ---"
		if [[ -x "$target/usr/libexec/bluetooth/bluetoothd" ]]; then
			echo "OK:  usr/libexec/bluetooth/bluetoothd"
		else
			echo "FAIL: bluetoothd missing (BlueZ 5.77 installs to usr/libexec/bluetooth/)" >&2
			echo "  Run: bash scripts/br-make-packages.sh bt bluez5_utils && make build-rootfs" >&2
			missing=1
		fi
		if [[ -x "$target/usr/bin/bluetoothctl" ]]; then
			echo "OK:  usr/bin/bluetoothctl"
		else
			echo "FAIL: bluetoothctl missing" >&2
			missing=1
		fi
		if [[ -f "$target/usr/lib/systemd/system/bluetooth.service" ]]; then
			echo "OK:  bluetooth.service unit"
		else
			echo "FAIL: bluetooth.service missing" >&2
			missing=1
		fi
	fi
	if grep -qF '#include "chips/lws_hmi_npu.config"' "$def" 2>/dev/null; then
		echo ""
		echo "--- RKNPU2 runtime (lws_hmi_npu.config) ---"
		if [[ -f "$target/usr/lib/librknnrt.so" ]]; then
			echo "OK:  usr/lib/librknnrt.so"
		else
			echo "FAIL: usr/lib/librknnrt.so missing (run: make fetch-rknn-rt && make apply-overlay && make build-rootfs)" >&2
			missing=1
		fi
		if [[ -x "$target/usr/bin/rknn_server" ]]; then
			echo "OK:  usr/bin/rknn_server"
		else
			echo "FAIL: usr/bin/rknn_server missing" >&2
			missing=1
		fi
		if [[ -e "$target/usr/bin/rknn_common_test" ]]; then
			echo "FAIL: rknn_common_test present (demo binary should be absent)" >&2
			missing=1
		else
			echo "OK:  rknn_common_test absent"
		fi
	fi

	check_rootfs_image "$out_dir" || missing=1

	echo ""
	if [[ "$missing" -eq 0 ]]; then
		echo "=== verify-rootfs-overlay: PASS ==="
		exit 0
	fi
	echo "=== verify-rootfs-overlay: FAIL ===" >&2
	exit 1
}

if [[ "${1:-}" == "--inside-docker" ]]; then
	run_check "$(resolve_br_target "${LWS_HMI_SDK_DIR:-/work/sdk}")"
	exit $?
fi

if [[ -z "$SDK" || ! -d "$SDK" ]]; then
	echo "ERROR: SDK not found at $SDK. Copy it to repo-root linux-sdk/." >&2
	exit 1
fi

run_check "$(resolve_br_target "$SDK")"
