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

	for unit in input-event-daemon.service lws-hmi-debug-boot.service ssh-debug-usb.service sshd.service sshd.socket bluetooth.service wifibt-init.service wpa_supplicant.service network.service log-guardian.service ssh-debug-lan.service wlan-wpa.service wlan-dhcp.service eth0-network.service; do
		if unit_wants_link "$unit"; then
			echo "FAIL: $unit still enabled in $label" >&2
			missing=1
		else
			echo "OK:  $unit not in $label wants"
		fi
	done

	for unit in hmi.service oem-compose.service mainserver.service cpu-performance.service pwrkey-poweroff.service usb-otg-role-boot.service ab-boot-confirm.service tee-supplicant.service; do
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
	if [[ -x "$root/usr/libexec/hmi/pre-poweroff.sh" && \
		-x "$root/usr/libexec/hmi/shutdown.sh" && \
		-x "$root/usr/libexec/hmi/systemctl-poweroff-wrapper.sh" ]]; then
		echo "OK:  pre-poweroff/shutdown/systemctl wrapper scripts present in $label"
	else
		echo "FAIL: missing graceful poweroff helper scripts in $label" >&2
		missing=1
	fi

	if [[ ! -L "$root/usr/bin/systemctl" ]]; then
		echo "FAIL: /usr/bin/systemctl not a symlink in $label" >&2
		missing=1
	elif [[ ! -x "$root/usr/bin/systemctl.real" ]]; then
		echo "FAIL: /usr/bin/systemctl.real missing in $label" >&2
		missing=1
	else
		case "$(readlink "$root/usr/bin/systemctl")" in
		../libexec/hmi/systemctl-poweroff-wrapper.sh) ;;
		*)
			echo "FAIL: /usr/bin/systemctl not wrapped in $label (readlink=$(readlink "$root/usr/bin/systemctl" 2>/dev/null))" >&2
			missing=1
			;;
		esac
		if [[ "$missing" -eq 0 ]] && [[ ! -e "$root/usr/bin/systemctl" ]]; then
			echo "FAIL: /usr/bin/systemctl symlink does not resolve in $label" >&2
			missing=1
		fi
	fi
	if [[ "$missing" -eq 0 ]]; then
		if [[ -L "$root/bin" && "$(readlink "$root/bin")" == "usr/bin" ]]; then
			echo "OK:  systemctl wrapper installed ($label: /bin merged into usr/bin)"
		elif [[ ! -L "$root/bin/systemctl" ]] || \
			[[ "$(readlink "$root/bin/systemctl")" != "../usr/bin/systemctl" ]]; then
			echo "FAIL: /bin/systemctl must symlink ../usr/bin/systemctl in $label" >&2
			missing=1
		else
			echo "OK:  systemctl wrapper + /bin symlink in $label"
		fi
	fi

	if [[ -f "$root/etc/systemd/system/systemd-poweroff.service.d/50-lws-hmi-pre-poweroff.conf" ]]; then
		echo "FAIL: retired systemd-poweroff drop-in still present in $label" >&2
		missing=1
	else
		echo "OK:  retired systemd-poweroff drop-in absent in $label"
	fi

	if [[ -L "$root/etc/systemd/system/poweroff.target.wants/lws-hmi-pre-poweroff.service" || \
		-f "$root/etc/systemd/system/poweroff.target.wants/lws-hmi-pre-poweroff.service" ]]; then
		echo "FAIL: retired pre-poweroff.service still linked in $label" >&2
		missing=1
	else
		echo "OK:  retired pre-poweroff.service not linked in $label"
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
	if [[ -d "$mnt/usr/lib/lws-hmi" || -d "$mnt/var/lib/lws-hmi" ]]; then
		echo "FAIL: legacy monolithic lws-hmi paths still present in rootfs.ext2" >&2
		rc=1
	else
		echo "OK:  no legacy usr/lib/lws-hmi or var/lib/lws-hmi in rootfs.ext2"
	fi
	stale_etc_names=""
	while IFS= read -r f; do
		[[ -n "$f" ]] || continue
		stale_etc_names="${stale_etc_names:+$stale_etc_names }${f#$mnt/}"
	done < <(find "$mnt/etc" -name '*lws-hmi*' 2>/dev/null || true)
	if [[ -n "$stale_etc_names" ]]; then
		echo "FAIL: rootfs.ext2 etc/ still has retired *lws-hmi* basenames: $stale_etc_names" >&2
		rc=1
	else
		echo "OK:  rootfs.ext2 etc/ has no *lws-hmi* basenames"
	fi
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
	local libexec_hmi="$target/usr/libexec/hmi"
	local libexec_wpa="$target/usr/libexec/wpa"
	local libexec_net="$target/usr/libexec/network"
	local libexec_bt="$target/usr/libexec/bluetooth"
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

	for tier in "$libexec_hmi" "$libexec_wpa" "$libexec_net" "$libexec_bt"; do
		if [[ ! -d "$tier" ]]; then
			echo "FAIL: $tier missing — overlay not applied or wrong Buildroot profile" >&2
			missing=1
		fi
	done
	if [[ -d "$target/usr/lib/lws-hmi" || -d "$target/var/lib/lws-hmi" ]]; then
		echo "FAIL: legacy monolithic lws-hmi paths still present in staging target" >&2
		[[ -d "$target/usr/lib/lws-hmi" ]] && echo "FAIL:   staging has usr/lib/lws-hmi" >&2
		[[ -d "$target/var/lib/lws-hmi" ]] && echo "FAIL:   staging has var/lib/lws-hmi" >&2
		missing=1
	else
		echo "OK:  no legacy usr/lib/lws-hmi or var/lib/lws-hmi in staging target"
	fi
	stale_etc="$(grep -r '/usr/lib/lws-hmi\|/var/lib/lws-hmi' "$target/etc" 2>/dev/null || true)"
	if [[ -n "$stale_etc" ]]; then
		echo "FAIL: etc/ still references removed monolithic lws-hmi paths (stale overlay layer?)" >&2
		printf '%s\n' "$stale_etc" >&2
		missing=1
	else
		echo "OK:  etc/ has no /usr/lib/lws-hmi or /var/lib/lws-hmi string refs"
	fi
	stale_etc_names=""
	while IFS= read -r f; do
		[[ -n "$f" ]] || continue
		stale_etc_names="${stale_etc_names:+$stale_etc_names }${f#$target/}"
	done < <(find "$target/etc" -name '*lws-hmi*' 2>/dev/null || true)
	if [[ -n "$stale_etc_names" ]]; then
		echo "FAIL: etc/ still has retired *lws-hmi* basenames: $stale_etc_names" >&2
		missing=1
	else
		echo "OK:  etc/ has no *lws-hmi* basenames"
	fi
	retired_unit=""
	for f in "$target/etc/systemd/system"/lws-hmi-*.service; do
		[[ -e "$f" ]] || continue
		retired_unit="${retired_unit:+$retired_unit }$(basename "$f")"
	done
	if [[ -n "$retired_unit" ]]; then
		echo "FAIL: retired lws-hmi-*.service units still in etc/systemd/system ($retired_unit)" >&2
		missing=1
	else
		echo "OK:  no retired lws-hmi-*.service units in etc/systemd/system"
	fi
	if [[ -f "$target/etc/profile.d/lws-hmi-serial-stty.sh" ]]; then
		echo "FAIL: retired etc/profile.d/lws-hmi-serial-stty.sh still present" >&2
		missing=1
	else
		echo "OK:  profile.d/lws-hmi-serial-stty.sh absent"
	fi
	if [[ -f "$target/etc/profile.d/serial-stty.sh" ]] && \
		grep -q '/usr/libexec/hmi/serial-console-stty.sh' \
		"$target/etc/profile.d/serial-stty.sh" 2>/dev/null; then
		echo "OK:  profile.d/serial-stty.sh uses /usr/libexec/hmi/"
	else
		echo "FAIL: profile.d/serial-stty.sh missing or still points at /usr/lib/lws-hmi/" >&2
		missing=1
	fi

	echo ""
	echo "--- usr/libexec/hmi ---"
	for f in boot-verify.sh env-verify.sh ynh960-display-init.sh oem-compose.sh set-performance-mode.sh serial-console-stty.sh ensure-sshd-hostkeys.sh usb-plug-ssh-recover.sh pwrkey-poweroff.sh pre-poweroff.sh shutdown.sh systemctl-poweroff-wrapper.sh reboot-loader read-device-serial.sh hmi-stop-and-wait.sh usb-otg-mode.sh usb-gadget-usb-state.sh usb-mtp-start.sh usb-mtp-stop.sh usb-plug-ssh-vbus-check.sh usb-plug-ssh-start.sh usb-plug-ssh-stop.sh lan-ssh-run.sh enable-ssh-debug.sh disable-ssh-debug.sh change-orientation.sh bind-prefs.sh push-app-apply-and-restart.sh hmi-launch.sh secrets-seal secrets-seal-ca; do
		if [[ -x "$libexec_hmi/$f" ]]; then
			echo "OK:  hmi/$f"
		else
			echo "FAIL: hmi/$f missing or not executable" >&2
			missing=1
		fi
	done
	if [[ -x "$target/usr/bin/umtprd" ]]; then
		echo "OK:  usr/bin/umtprd"
	else
		echo "FAIL: usr/bin/umtprd missing (make build-umtprd)" >&2
		missing=1
	fi
	if [[ -f "$target/usr/lib/optee_armtz/b8e4f2a1-9c3d-4e6f-8a1b-2c3d4e5f6071.ta" ]] \
		|| [[ -f "$target/lib/optee_armtz/b8e4f2a1-9c3d-4e6f-8a1b-2c3d4e5f6071.ta" ]]; then
		echo "OK:  usr/lib/optee_armtz seal TA"
	else
		echo "FAIL: seal TA missing (make build-secrets-seal)" >&2
		missing=1
	fi
	if [[ -f "$libexec_hmi/paths.sh" ]]; then
		echo "OK:  hmi/paths.sh"
	else
		echo "FAIL: hmi/paths.sh missing" >&2
		missing=1
	fi

	echo ""
	echo "--- usr/libexec/wpa ---"
	for f in run-wpa.sh wifi-stack-up.sh wifi-stack-down.sh wlan0-dhcp.sh wlan0-static.sh; do
		if [[ -x "$libexec_wpa/$f" ]]; then
			echo "OK:  wpa/$f"
		else
			echo "FAIL: wpa/$f missing or not executable" >&2
			missing=1
		fi
	done
	# time-sync.sh retired — HAL LinuxDateTimeController owns clock sync.
	echo "OK:  time-sync via HAL (no hmi/time-sync.sh)"

	echo ""
	echo "--- usr/libexec/network ---"
	for f in apply-eth0.sh eth0-dhcp.sh eth0-static.sh eth0-link.sh eth0-tune.sh networkd-apply-ipv4.sh; do
		if [[ -x "$libexec_net/$f" ]]; then
			echo "OK:  network/$f"
		else
			echo "FAIL: network/$f missing or not executable" >&2
			missing=1
		fi
	done

	echo ""
	echo "--- usr/libexec/bluetooth ---"
	for f in bt-stack-up.sh bt-stack-down.sh bt-pair-agent.sh bt-ensure-agent.sh bt-stop-agent.sh bt-set-alias.sh bt-trust-paired.sh wifibt-bringup.sh bt-hid-check.sh; do
		if [[ -x "$libexec_bt/$f" ]]; then
			echo "OK:  bluetooth/$f"
		else
			echo "FAIL: bluetooth/$f missing or not executable" >&2
			missing=1
		fi
	done
	for retired in bt-hid-heal.sh bt-hid-heal-loop.sh; do
		if [[ -e "$libexec_bt/$retired" ]]; then
			echo "FAIL: bluetooth/$retired must be retired" >&2
			missing=1
		else
			echo "OK:  bluetooth/$retired absent (HAL heal)"
		fi
	done

	echo ""
	echo "--- subsystem state seed dirs ---"
	if [[ -f "$target/var/lib/wpa_supplicant/wpa_supplicant.conf" ]]; then
		echo "OK:  var/lib/wpa_supplicant/wpa_supplicant.conf"
	else
		echo "FAIL: var/lib/wpa_supplicant/wpa_supplicant.conf missing" >&2
		missing=1
	fi
	if [[ -f "$target/var/lib/network/eth0-ipv4" ]]; then
		echo "OK:  var/lib/network/eth0-ipv4"
	else
		echo "FAIL: var/lib/network/eth0-ipv4 missing" >&2
		missing=1
	fi
	if [[ -f "$target/var/lib/hmi/http-proxy" ]]; then
		echo "OK:  var/lib/hmi/http-proxy (legacy; apply-proxy migrates)"
	else
		echo "WARN: var/lib/hmi/http-proxy missing (optional after migrate)"
	fi
	if [[ -f "$target/var/lib/network/proxy.conf" ]]; then
		echo "OK:  var/lib/network/proxy.conf"
	else
		echo "FAIL: var/lib/network/proxy.conf missing" >&2
		missing=1
	fi
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
		echo "FAIL: aic8800_fdrv.ko missing — enable ynh960 wifibt kernel config, rebuild kernel+rootfs" >&2
		missing=1
	fi
	# Combo firmware lives in OEM radio pack — rootfs must not carry kitchen sink
	# or leftover AIC blobs from older Innohi dumps.
	_fw_hit=""
	for _fw_dir in \
		"$target/usr/lib/firmware" \
		"$target/lib/firmware" \
		"$target/vendor/etc/firmware" \
		"$target/system/etc/firmware"; do
		[[ -d "$_fw_dir" ]] || continue
		_fw_real="$(readlink -f "$_fw_dir" 2>/dev/null || echo "$_fw_dir")"
		[[ -d "$_fw_real" ]] || continue
		if compgen -G "$_fw_real/fw_bcm*" >/dev/null 2>&1; then
			_fw_hit="${_fw_hit}fw_bcm* under ${_fw_real#"$target"} "
		fi
	done
	if [[ -n "$_fw_hit" ]]; then
		echo "FAIL: Wi-Fi/BT kitchen-sink firmware present ($_fw_hit)— OEM radio pack owns combo FW" >&2
		missing=1
	else
		echo "OK:  no fw_bcm* kitchen-sink under firmware dirs"
	fi
	if compgen -G "$target/vendor/lib/modules/bcmdhd*.ko" >/dev/null 2>&1 || \
		compgen -G "$target/lib/modules/bcmdhd*.ko" >/dev/null 2>&1 || \
		compgen -G "$target/lib/modules/*/bcmdhd*.ko" >/dev/null 2>&1; then
		echo "FAIL: bcmdhd*.ko present — not selected for this product line" >&2
		missing=1
	else
		echo "OK:  bcmdhd*.ko absent"
	fi
	unset _fw_hit _fw_dir _fw_real
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
verify-boot /usr/libexec/hmi/boot-verify.sh
verify-env /usr/libexec/hmi/env-verify.sh
diagnose-hmi /usr/libexec/hmi/diagnose-hmi.sh
diagnose-usb-ssh /usr/libexec/hmi/usb-plug-ssh-diag.sh
read-serial /usr/libexec/hmi/read-device-serial.sh
start-usb-ssh /usr/libexec/hmi/usb-plug-ssh-start.sh
stop-usb-ssh /usr/libexec/hmi/usb-plug-ssh-stop.sh
recover-usb-ssh /usr/libexec/hmi/usb-plug-ssh-recover.sh
reboot-loader /usr/libexec/hmi/reboot-loader
change-orientation /usr/libexec/hmi/change-orientation.sh
enable-ssh-debug /usr/libexec/hmi/enable-ssh-debug.sh
disable-ssh-debug /usr/libexec/hmi/disable-ssh-debug.sh
usb-otg-mode /usr/libexec/hmi/usb-otg-mode.sh
set-performance-mode /usr/libexec/hmi/set-performance-mode.sh
apply-mouse-settings /usr/libexec/hmi/apply-mouse-settings.sh
EOF
	for retired in boot-verify env-verify read-device-serial reboot-rockusb-loader lws-hmi-backlight-apply change-backlight change-volume apply-proxy sync-time; do
		if [[ -e "$target/usr/bin/$retired" || -L "$target/usr/bin/$retired" ]]; then
			echo "FAIL: retired usr/bin/$retired command still present" >&2
			missing=1
		else
			echo "OK:  retired usr/bin/$retired command absent"
		fi
	done
	if [[ -e "$target/usr/libexec/hmi/reboot-rockusb-loader" ]]; then
		echo "FAIL: retired usr/libexec/hmi/reboot-rockusb-loader still present" >&2
		missing=1
	fi

	if [[ -f "$target/etc/systemd/system/hmi.service" ]]; then
		echo "OK:  hmi.service in target"
	else
		echo "FAIL: hmi.service missing from target/etc/systemd/system" >&2
		missing=1
	fi
	if [[ -f "$target/etc/systemd/system/oem-compose.service" ]]; then
		echo "OK:  oem-compose.service in target"
	else
		echo "FAIL: oem-compose.service missing from target/etc/systemd/system" >&2
		missing=1
	fi
	if [[ -e "$target/usr/share/hmi/oem-fallback" ]]; then
		echo "FAIL: usr/share/hmi/oem-fallback must be removed (no OEM migration fallback)" >&2
		missing=1
	else
		echo "OK:  oem-fallback absent (compose fails hard without /oem)"
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
		"$target/etc/systemd/system/ssh-debug-usb.service" \
		"$target/etc/systemd/system/serial-stty.service" \
		"$target/etc/udev/rules.d/99-usb-plug-ssh.rules" \
		"$target/etc/ssh/sshd_config.d/50-ssh-auth.conf" \
		"$target/etc/profile.d/serial-stty.sh" \
		"$target/etc/issue.d/00-terminal-resize.issue"; do
		if [[ -e "$f" ]]; then
			echo "OK:  ${f#$target/}"
		else
			echo "FAIL: missing ${f#$target/}" >&2
			missing=1
		fi
	done
	if grep -q 'ListenAddress=192.168.55.1' "$libexec_hmi/usb-plug-ssh-start.sh" 2>/dev/null; then
		echo "OK:  usb-plug-ssh-start binds ListenAddress=192.168.55.1"
	else
		echo "FAIL: usb-plug-ssh-start missing ListenAddress=192.168.55.1 override" >&2
		missing=1
	fi
	if grep -q 'skip USB-only sshd' "$libexec_hmi/usb-plug-ssh-start.sh" 2>/dev/null; then
		echo "FAIL: usb-plug-ssh-start must not skip USB sshd when LAN is up" >&2
		missing=1
	else
		echo "OK:  usb-plug-ssh-start always starts usb0-only sshd"
	fi
	legacy_sshd=""
	for f in "$target/etc/ssh/sshd_config.d/"*.conf; do
		[[ -f "$f" ]] || continue
		if grep -qE '^[[:space:]]*ListenAddress[[:space:]]+192\.168\.55\.1' "$f" 2>/dev/null; then
			legacy_sshd="${legacy_sshd:+$legacy_sshd }${f#$target/}"
		fi
	done
	if [[ -n "$legacy_sshd" ]]; then
		echo "FAIL: global sshd_config.d still forces ListenAddress 192.168.55.1 ($legacy_sshd)" >&2
		missing=1
	else
		echo "OK:  sshd_config.d does not force USB-only ListenAddress"
	fi
	if [[ -e "$target/etc/ssh/sshd_config.d/50-lws-hmi-usb-plug-ssh.conf" ]]; then
		echo "FAIL: retired 50-lws-hmi-usb-plug-ssh.conf still present" >&2
		missing=1
	fi
	if ls "$target/etc/ssh"/ssh_host_*_key >/dev/null 2>&1; then
		echo "OK:  ssh host keys present in etc/ssh"
	else
		echo "FAIL: missing /etc/ssh/ssh_host_*_key (ensure-sshd-hostkeys / post-fakeroot)" >&2
		missing=1
	fi
	if grep -q 'modprobe g_ether' "$libexec_hmi/usb-plug-ssh-start.sh" 2>/dev/null && \
		! grep -q '/sys/kernel/config/usb_gadget/lws_hmi' "$libexec_hmi/usb-plug-ssh-start.sh" 2>/dev/null; then
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
	for jit in kernel_blob.bin isolate_snapshot_data vm_snapshot_data; do
		if [[ -f "$target/opt/hmi/data/flutter_assets/$jit" ]]; then
			echo "FAIL: opt/hmi/data/flutter_assets/$jit present (release AOT only; post-build must purge)" >&2
			missing=1
		else
			echo "OK:  opt/hmi/data/flutter_assets/$jit absent (no JIT in product rootfs)"
		fi
	done
	if [[ -f "$target/opt/hmi/lib/librknnrt.so" ]]; then
		echo "FAIL: opt/hmi/lib/librknnrt.so present (use /usr/lib only; build-ai must not stage it)" >&2
		missing=1
	else
		echo "OK:  opt/hmi/lib/librknnrt.so absent (system RKNN)"
	fi
	if [[ -e "$target/opt/hmi/bin/ffmpeg" ]]; then
		echo "FAIL: opt/hmi/bin/ffmpeg present (covers/AI samples use extract-video-frame)" >&2
		missing=1
	else
		echo "OK:  opt/hmi/bin/ffmpeg absent (GStreamer frame extract)"
	fi
	if [[ -x "$target/usr/libexec/hmi/extract-video-frame" ]]; then
		echo "OK:  usr/libexec/hmi/extract-video-frame present"
	else
		echo "FAIL: usr/libexec/hmi/extract-video-frame missing" >&2
		missing=1
	fi

	echo ""
	echo "--- systemd udev hwdb (bin only) ---"
	if [[ -f "$target/usr/lib/udev/hwdb.bin" ]]; then
		echo "OK:  usr/lib/udev/hwdb.bin present"
	else
		echo "FAIL: usr/lib/udev/hwdb.bin missing (BR2_PACKAGE_SYSTEMD_HWDB)" >&2
		missing=1
	fi
	_hwdb_src=""
	while IFS= read -r -d '' _f; do
		_hwdb_src="${_hwdb_src}${_f#"$target"/}"$'\n'
	done < <(find "$target/usr/lib/udev/hwdb.d" "$target/etc/udev/hwdb.d" \
		-type f -name '*.hwdb' -print0 2>/dev/null || true)
	if [[ -n "$_hwdb_src" ]]; then
		echo "FAIL: hwdb.d sources must not ship (post-build keeps bin only):" >&2
		printf '%s' "$_hwdb_src" >&2
		missing=1
	else
		echo "OK:  no *.hwdb under usr/lib/udev/hwdb.d or etc/udev/hwdb.d"
	fi
	unset _hwdb_src _f

	# Optional second Flutter app (factory_test) when source tree exists.
	if [[ -f "$ROOT/app/factory_test/pubspec.yaml" ]]; then
		echo ""
		echo "--- /opt/factory_test (optional Flutter app — no engine) ---"
		for f in \
			"$target/opt/factory_test/lib/libapp.so" \
			"$target/opt/factory_test/data/flutter_assets/AssetManifest.bin"; do
			if [[ -e "$f" ]]; then
				echo "OK:  ${f#$target/}"
			else
				echo "FAIL: missing ${f#$target/} (app/factory_test present; run: make build-rootfs)" >&2
				missing=1
			fi
		done
		if [[ -f "$target/opt/factory_test/lib/libflutter_engine.so" ]]; then
			echo "FAIL: opt/factory_test/lib/libflutter_engine.so present (engine belongs in /usr/lib only)" >&2
			missing=1
		else
			echo "OK:  opt/factory_test/lib/libflutter_engine.so absent (system engine)"
		fi
		if [[ -f "$target/opt/factory_test/data/icudtl.dat" ]]; then
			echo "FAIL: opt/factory_test/data/icudtl.dat present (use /usr/share/flutter on rootfs)" >&2
			missing=1
		else
			echo "OK:  opt/factory_test/data/icudtl.dat absent (system icu)"
		fi
		for jit in kernel_blob.bin isolate_snapshot_data vm_snapshot_data; do
			if [[ -f "$target/opt/factory_test/data/flutter_assets/$jit" ]]; then
				echo "FAIL: opt/factory_test/data/flutter_assets/$jit present (release AOT only)" >&2
				missing=1
			else
				echo "OK:  opt/factory_test/data/flutter_assets/$jit absent (no JIT)"
			fi
		done
	fi
	if [[ -f "$target/usr/lib/libflutter_engine.so" ]]; then
		system_sz="$(stat -c%s "$target/usr/lib/libflutter_engine.so" 2>/dev/null || stat -f%z "$target/usr/lib/libflutter_engine.so")"
		echo "OK:  usr/lib/libflutter_engine.so ($system_sz bytes)"
	else
		echo "FAIL: usr/lib/libflutter_engine.so missing (flutter-engine / post-hook sync)" >&2
		missing=1
	fi

	echo ""
	echo "--- display (Weston + eLinux client) ---"
	has_weston=0
	if [[ -x "$target/usr/bin/weston" && \
		-x "$target/usr/bin/flutter-wayland-client" ]]; then
		has_weston=1
	fi
	if [[ -x "$target/usr/bin/flutter-pi" ]]; then
		echo "FAIL: flutter-pi binary must not ship" >&2
		missing=1
	fi
	if [[ -e "$target/usr/bin/adbd" || -e "$target/sbin/adbd" || -e "$target/system/bin/adbd" ]]; then
		echo "FAIL: adbd binary must not ship (P1; post-build must purge leftovers)" >&2
		missing=1
	else
		echo "OK:  adbd binary absent"
	fi
	if [[ -e "$target/etc/profile.d/adbd.sh" ]]; then
		echo "FAIL: etc/profile.d/adbd.sh must not ship" >&2
		missing=1
	else
		echo "OK:  etc/profile.d/adbd.sh absent"
	fi
	if [[ -f "$target/etc/display-stack" || -f "$target/etc/hmi/display-stack" ]]; then
		echo "FAIL: retired display-stack stamp must not ship" >&2
		missing=1
	else
		echo "OK:  no display-stack stamp"
	fi
	if [[ "$has_weston" -eq 1 ]]; then
		echo "OK:  weston image (flutter-wayland-client)"
		# Unpatched GStreamer video plugin SIGSEGVs on live RTSP initialize.
		vp="$target/usr/lib/libvideo_player_plugin.so"
		if [[ -f "$vp" ]]; then
			if ! strings "$vp" | grep -q 'Video size unknown after preroll'; then
				echo "FAIL: $vp missing live-RTSP patch (will segfault in IP Camera)" >&2
				missing=1
			elif ! strings "$vp" | grep -q 'MppElementSetup: mppvideodec format=RGBA'; then
				echo "FAIL: $vp missing MPP RGBA patch" >&2
				missing=1
			else
				echo "OK:  libvideo_player_plugin.so has live-RTSP + MPP RGBA markers"
			fi
		else
			echo "FAIL: weston image missing $vp" >&2
			missing=1
		fi
	else
		echo "FAIL: Weston + flutter-wayland-client not present" >&2
		missing=1
	fi

	for f in \
		"$target/etc/systemd/system/lws-hmi-debug-boot.service" \
		"$target/etc/systemd/system/lws-hmi-boot-kpi.service" \
		"$target/usr/libexec/hmi/debug-boot.sh" \
		"$target/usr/libexec/hmi/boot-kpi-watch.sh" \
		"$target/usr/libexec/hmi/configure-camera-eth0.sh"; do
		if [[ -e "$f" ]]; then
			echo "FAIL: retired artifact still in target: $f" >&2
			missing=1
		else
			echo "OK:  $(basename "$f") absent from target"
		fi
	done

	if [[ -e "$target/usr/libexec/hmi/render-mediamtx-config.sh" ]]; then
		echo "FAIL: render-mediamtx-config.sh must not ship in rootfs (App-owned MediaMTX)" >&2
		missing=1
	else
		echo "OK:  render-mediamtx-config.sh absent (App Dart writer)"
	fi
	if [[ -e "$target/usr/bin/mediamtx" ]]; then
		echo "FAIL: /usr/bin/mediamtx must not ship in rootfs (use /opt/hmi/bin)" >&2
		missing=1
	else
		echo "OK:  /usr/bin/mediamtx absent"
	fi
	if [[ -e "$target/etc/systemd/system/mediamtx.service" ]]; then
		echo "FAIL: mediamtx.service must not ship in rootfs" >&2
		missing=1
	else
		echo "OK:  mediamtx.service absent"
	fi

	if [[ -x "$target/usr/libexec/hmi/enable-ssh-debug.sh" && -x "$target/usr/libexec/hmi/disable-ssh-debug.sh" ]]; then
		echo "OK:  enable-ssh-debug.sh / disable-ssh-debug.sh"
	else
		echo "FAIL: missing enable-ssh-debug.sh or disable-ssh-debug.sh" >&2
		missing=1
	fi
	if [[ -f "$target/etc/systemd/system/wlan-wpa.service" ]] && \
		grep -q 'run-wpa.sh' \
		"$target/etc/systemd/system/wlan-wpa.service" 2>/dev/null; then
		echo "OK:  wlan-wpa.service"
	else
		echo "FAIL: missing wlan-wpa.service (Wi-Fi must outlive hmi stop)" >&2
		missing=1
	fi
	if grep -q '^DefaultDependencies=no$' \
		"$target/etc/systemd/system/wlan-wpa.service" 2>/dev/null || \
		! grep -q '^RequiresMountsFor=/var/lib/wpa_supplicant$' \
			"$target/etc/systemd/system/wlan-wpa.service" 2>/dev/null; then
		echo "FAIL: wlan-wpa.service needs normal deps + RequiresMountsFor=/var/lib/wpa_supplicant" >&2
		missing=1
	else
		echo "OK:  wlan-wpa.service has normal shutdown/umount ordering"
	fi
	if [[ -f "$target/etc/systemd/system/wlan-dhcp.service" ]]; then
		echo "OK:  wlan-dhcp.service"
	else
		echo "FAIL: missing wlan-dhcp.service" >&2
		missing=1
	fi
	if grep -q 'wlan-wpa.service' \
		"$target/etc/systemd/system-preset/99-appliance.preset" 2>/dev/null && \
		grep -q 'wlan-dhcp.service' \
		"$target/etc/systemd/system-preset/99-appliance.preset" 2>/dev/null && \
		grep -q 'eth0-network.service' \
		"$target/etc/systemd/system-preset/99-appliance.preset" 2>/dev/null; then
		echo "OK:  preset disables wlan-wpa / wlan-dhcp / eth0"
	else
		echo "FAIL: preset missing disable for settings network units" >&2
		missing=1
	fi
	if grep -qE '^enable[[:space:]]+systemd-networkd\.service' \
		"$target/etc/systemd/system-preset/99-appliance.preset" 2>/dev/null; then
		echo "OK:  preset enables systemd-networkd.service"
	else
		echo "FAIL: preset must enable systemd-networkd.service (D11)" >&2
		missing=1
	fi
	if grep -qE '^enable[[:space:]]+systemd-resolved\.service' \
		"$target/etc/systemd/system-preset/99-appliance.preset" 2>/dev/null; then
		echo "OK:  preset enables systemd-resolved.service"
	else
		echo "FAIL: preset must enable systemd-resolved.service (D11 DNS)" >&2
		missing=1
	fi
	if grep -qE '^enable[[:space:]]+systemd-timesyncd\.service' \
		"$target/etc/systemd/system-preset/99-appliance.preset" 2>/dev/null; then
		echo "OK:  preset enables systemd-timesyncd.service (Automatic NTP default on)"
	else
		echo "FAIL: preset must enable systemd-timesyncd.service (Automatic NTP default on)" >&2
		missing=1
	fi
	if grep -qE '^enable[[:space:]]+rtc-systohc\.timer' \
		"$target/etc/systemd/system-preset/99-appliance.preset" 2>/dev/null && \
		[[ -f "$target/etc/systemd/system/rtc-systohc.service" ]] && \
		[[ -f "$target/etc/systemd/system/rtc-systohc.timer" ]]; then
		echo "OK:  rtc-systohc.timer enabled (external RTC systohc; offline-friendly)"
	else
		echo "FAIL: missing rtc-systohc units or preset enable" >&2
		missing=1
	fi
	if grep -qE 'fake-hwclock' \
		"$target/etc/systemd/system-preset/99-appliance.preset" 2>/dev/null || \
		[[ -f "$target/etc/systemd/system/fake-hwclock-load.service" ]] || \
		[[ -f "$target/usr/libexec/hmi/fake-hwclock.sh" ]]; then
		echo "FAIL: fake-hwclock must be removed (use external pcf8563 RTC)" >&2
		missing=1
	fi
	if [[ -f "$target/etc/systemd/timesyncd.conf.d/10-appliance.conf" ]] && \
		grep -qE '^NTP=pool\.ntp\.org' \
		"$target/etc/systemd/timesyncd.conf.d/10-appliance.conf" 2>/dev/null && \
		grep -qE 'time\.cloudflare\.com' \
		"$target/etc/systemd/timesyncd.conf.d/10-appliance.conf" 2>/dev/null && \
		grep -qE 'time\.google\.com' \
		"$target/etc/systemd/timesyncd.conf.d/10-appliance.conf" 2>/dev/null && \
		grep -qE 'ntp\.aliyun\.com' \
		"$target/etc/systemd/timesyncd.conf.d/10-appliance.conf" 2>/dev/null; then
		echo "OK:  timesyncd.conf.d NTP=pool.ntp.org; FallbackNTP=cloudflare→google→aliyun"
	else
		echo "FAIL: missing timesyncd.conf.d/10-appliance.conf with pool→CF→Google→Aliyun" >&2
		missing=1
	fi

	echo ""
	echo "--- D11 networkd + resolved + wpa D-Bus (no legacy L3) ---"
	netd_bin=""
	for p in "$target/lib/systemd/systemd-networkd" \
		"$target/usr/lib/systemd/systemd-networkd"; do
		if [[ -x "$p" ]]; then
			netd_bin=$p
			break
		fi
	done
	if [[ -n "$netd_bin" ]]; then
		echo "OK:  systemd-networkd binary (${netd_bin#$target})"
	else
		echo "FAIL: systemd-networkd binary missing (br-make-packages systemd systemd)" >&2
		missing=1
	fi
	resolved_bin=""
	for p in "$target/lib/systemd/systemd-resolved" \
		"$target/usr/lib/systemd/systemd-resolved"; do
		if [[ -x "$p" ]]; then
			resolved_bin=$p
			break
		fi
	done
	if [[ -n "$resolved_bin" ]]; then
		echo "OK:  systemd-resolved binary (${resolved_bin#$target})"
	else
		echo "FAIL: systemd-resolved binary missing (br-make-packages systemd systemd)" >&2
		missing=1
	fi
	if [[ -x "$target/usr/bin/networkctl" ]] || [[ -x "$target/bin/networkctl" ]]; then
		echo "OK:  networkctl present"
	else
		echo "FAIL: networkctl missing in staging target" >&2
		missing=1
	fi
	if [[ -f "$target/lib/systemd/system/systemd-networkd.service" ]] || \
		[[ -f "$target/usr/lib/systemd/system/systemd-networkd.service" ]]; then
		echo "OK:  systemd-networkd.service unit"
	else
		echo "FAIL: systemd-networkd.service unit missing" >&2
		missing=1
	fi
	if [[ -f "$target/lib/systemd/system/systemd-resolved.service" ]] || \
		[[ -f "$target/usr/lib/systemd/system/systemd-resolved.service" ]]; then
		echo "OK:  systemd-resolved.service unit"
	else
		echo "FAIL: systemd-resolved.service unit missing" >&2
		missing=1
	fi
	if [[ -L "$target/etc/resolv.conf" ]]; then
		_rl="$(readlink "$target/etc/resolv.conf")"
		case "$_rl" in
		*systemd/resolve/*)
			echo "OK:  /etc/resolv.conf → resolved ($_rl)"
			;;
		*)
			echo "FAIL: /etc/resolv.conf must point at systemd-resolved (got $_rl)" >&2
			missing=1
			;;
		esac
	else
		echo "FAIL: /etc/resolv.conf must be symlink to systemd-resolved" >&2
		missing=1
	fi
	if [[ -f "$target/etc/systemd/resolved.conf.d/10-appliance.conf" ]]; then
		echo "OK:  resolved.conf.d/10-appliance.conf present"
	else
		echo "FAIL: resolved.conf.d/10-appliance.conf missing" >&2
		missing=1
	fi
	if [[ -x "$target/usr/sbin/wpa_supplicant" ]] && \
		strings "$target/usr/sbin/wpa_supplicant" 2>/dev/null | grep -q 'dbus_bus_request_name'; then
		echo "OK:  wpa_supplicant linked with D-Bus"
	elif [[ -x "$target/usr/sbin/wpa_supplicant" ]]; then
		# strings may miss; require help text after qemu — check overlay run-wpa contract instead
		echo "WARN: could not confirm wpa D-Bus symbols via strings"
	else
		echo "FAIL: wpa_supplicant missing" >&2
		missing=1
	fi
	if grep -qE '(^|[[:space:]])udhcpc([[:space:]]|$)|apply_legacy|legacy_dhcp|sync_resolv' \
		"$libexec_net/networkd-apply-ipv4.sh" 2>/dev/null; then
		echo "FAIL: networkd-apply-ipv4.sh must not contain legacy DHCP or resolv sync (D11)" >&2
		missing=1
	else
		echo "OK:  networkd-apply-ipv4.sh is networkd-only (DNS via resolved)"
	fi
	if grep -q 'networkctl missing' "$libexec_net/networkd-apply-ipv4.sh" 2>/dev/null && \
		grep -q 'FATAL' "$libexec_net/networkd-apply-ipv4.sh" 2>/dev/null; then
		echo "OK:  networkd-apply-ipv4.sh fails hard without networkctl"
	else
		echo "FAIL: networkd-apply-ipv4.sh must FATAL without networkctl" >&2
		missing=1
	fi
	if grep -qE 'FATAL:.*-u|has no -u' "$libexec_wpa/run-wpa.sh" 2>/dev/null; then
		echo "OK:  run-wpa.sh requires wpa -u"
	else
		echo "FAIL: run-wpa.sh must require D-Bus -u" >&2
		missing=1
	fi
	if [[ -e "$target/usr/sbin/dhcpcd" ]] || [[ -e "$target/sbin/dhcpcd" ]]; then
		echo "FAIL: dhcpcd still in target — L3 is networkd only (D11)" >&2
		missing=1
	else
		echo "OK:  dhcpcd absent from target"
	fi
	if grep -q 'BR2_PACKAGE_SYSTEMD_NETWORKD=y' \
		"$ROOT/overlay/buildroot/chips/lws_hmi_systemd.config" 2>/dev/null; then
		echo "OK:  chips/lws_hmi_systemd.config enables NETWORKD"
	else
		echo "FAIL: chips/lws_hmi_systemd.config missing BR2_PACKAGE_SYSTEMD_NETWORKD=y" >&2
		missing=1
	fi
	if grep -q 'BR2_PACKAGE_SYSTEMD_RESOLVED=y' \
		"$ROOT/overlay/buildroot/chips/lws_hmi_systemd.config" 2>/dev/null; then
		echo "OK:  chips/lws_hmi_systemd.config enables RESOLVED"
	else
		echo "FAIL: chips/lws_hmi_systemd.config missing BR2_PACKAGE_SYSTEMD_RESOLVED=y" >&2
		missing=1
	fi
	if grep -q 'BR2_PACKAGE_WPA_SUPPLICANT_DBUS=y' \
		"$ROOT/overlay/buildroot/chips/lws_hmi_network.config" 2>/dev/null; then
		echo "OK:  chips/lws_hmi_network.config enables WPA_SUPPLICANT_DBUS"
	else
		echo "FAIL: chips/lws_hmi_network.config missing BR2_PACKAGE_WPA_SUPPLICANT_DBUS=y" >&2
		missing=1
	fi
	if grep -q 'wlan-wpa.service' "$libexec_wpa/wifi-stack-up.sh" 2>/dev/null && \
		! grep -qE 'wpa_supplicant[[:space:]]+-B' "$libexec_wpa/wifi-stack-up.sh" 2>/dev/null; then
		echo "OK:  wifi-stack-up starts wlan-wpa.service (not hmi-cgroup -B)"
	else
		echo "FAIL: wifi-stack-up must start wlan-wpa.service instead of wpa -B" >&2
		missing=1
	fi
	if grep -q 'WantedBy=' \
		"$target/etc/systemd/system/wlan-wpa.service" 2>/dev/null || \
		grep -q 'WantedBy=' \
		"$target/etc/systemd/system/wlan-dhcp.service" 2>/dev/null || \
		grep -q 'WantedBy=' \
		"$target/etc/systemd/system/eth0-network.service" 2>/dev/null; then
		echo "FAIL: on-demand settings units must not have [Install] WantedBy" >&2
		missing=1
	fi
	if [[ -f "$target/etc/systemd/system/eth0-network.service" ]] && \
		[[ -x "$libexec_net/apply-eth0.sh" ]]; then
		echo "OK:  eth0-network.service + apply-eth0.sh"
	else
		echo "FAIL: missing eth0-network.service / apply-eth0.sh" >&2
		missing=1
	fi
	if [[ -e "$target/etc/systemd/system/settings-restore.service" ]] || \
		[[ -e "$libexec_hmi/restore-settings.sh" ]]; then
		echo "FAIL: settings-restore retired — HAL BoardBindings.restorePersistedSettings" >&2
		missing=1
	else
		echo "OK:  settings-restore retired (HAL-owned restore)"
	fi
	if [[ -x "$libexec_hmi/bind-prefs.sh" ]] && \
		( grep -q 'bind-prefs.sh' \
			"$libexec_hmi/ynh960-display-init.sh" 2>/dev/null || \
		  grep -q 'bind-prefs.sh' \
			"$ROOT/oem/boards/ynh960/helpers/display-init.sh" 2>/dev/null ); then
		echo "OK:  bind-prefs (four /var/lib/* → /userdata/*)"
	else
		echo "FAIL: missing bind-prefs.sh wired into display-init (stub or OEM helper)" >&2
		missing=1
	fi
	if grep -q 'enable hmi.service' \
		"$target/etc/systemd/system-preset/99-appliance.preset" 2>/dev/null; then
		echo "OK:  preset enables hmi.service"
	else
		echo "FAIL: preset must enable hmi.service" >&2
		missing=1
	fi
	if grep -q 'enable oem-compose.service' \
		"$target/etc/systemd/system-preset/99-appliance.preset" 2>/dev/null; then
		echo "OK:  preset enables oem-compose.service"
	else
		echo "FAIL: preset must enable oem-compose.service" >&2
		missing=1
	fi
	if grep -q 'settings-restore' \
		"$target/etc/systemd/system-preset/99-appliance.preset" 2>/dev/null; then
		echo "FAIL: preset must not enable settings-restore.service" >&2
		missing=1
	else
		echo "OK:  preset has no settings-restore"
	fi

	if [[ -f "$target/etc/systemd/system/ssh-debug-lan.service" ]]; then
		echo "OK:  ssh-debug-lan.service"
	else
		echo "FAIL: missing ssh-debug-lan.service" >&2
		missing=1
	fi
	if grep -q 'ssh-debug-lan.service' \
		"$target/etc/systemd/system-preset/99-appliance.preset" 2>/dev/null; then
		echo "OK:  preset disables ssh-debug-lan.service"
	else
		echo "FAIL: preset missing disable ssh-debug-lan.service" >&2
		missing=1
	fi
	if [[ -x "$target/usr/libexec/hmi/lan-ssh-run.sh" ]]; then
		echo "OK:  lan-ssh-run.sh"
	else
		echo "FAIL: missing lan-ssh-run.sh" >&2
		missing=1
	fi
	if grep -q 'Type=simple' \
		"$target/etc/systemd/system/ssh-debug-lan.service" 2>/dev/null && \
		grep -q 'lan-ssh-run.sh' \
		"$target/etc/systemd/system/ssh-debug-lan.service" 2>/dev/null; then
		echo "OK:  ssh-debug-lan.service uses Type=simple + lan-ssh-run.sh"
	else
		echo "FAIL: ssh-debug-lan.service must ExecStart lan-ssh-run.sh" >&2
		missing=1
	fi

	echo ""
	echo "--- A/B upgrade helpers (P2.4) ---"
	for f in \
		"$target/usr/libexec/hmi/ab-slot-lib.sh" \
		"$target/usr/libexec/hmi/ab-upgrade-apply.sh" \
		"$target/usr/libexec/hmi/ab-boot-confirm.sh" \
		"$target/etc/systemd/system/ab-boot-confirm.service"; do
		if [[ -e "$f" ]]; then
			echo "OK:  ${f#$target/}"
		else
			echo "FAIL: missing ${f#$target/}" >&2
			missing=1
		fi
	done
	if [[ -e "$target/usr/libexec/hmi/ab-upgrade-app-only.sh" ]]; then
		echo "FAIL: retired ab-upgrade-app-only.sh still present (use make push-app)" >&2
		missing=1
	else
		echo "OK:  retired ab-upgrade-app-only.sh absent"
	fi
	if grep -q 'ab_current_root_dev' "$target/usr/libexec/hmi/ab-slot-lib.sh" 2>/dev/null && \
		grep -q '^AB_MISC_OFFSET=1048576$' "$target/usr/libexec/hmi/ab-slot-lib.sh" 2>/dev/null && \
		grep -q 'ab_slot_marker_valid' "$target/usr/libexec/hmi/ab-slot-lib.sh" 2>/dev/null && \
		grep -q 'LWS_HMI_AB_LIB' "$target/usr/libexec/hmi/ab-upgrade-apply.sh" 2>/dev/null && \
		grep -q 'ab_same_block_device' "$target/usr/libexec/hmi/ab-upgrade-apply.sh" 2>/dev/null && \
		grep -q 'metadata_active' "$target/usr/libexec/hmi/ab-upgrade-apply.sh" 2>/dev/null && \
		grep -q 'disagrees with mounted root' "$target/usr/libexec/hmi/ab-upgrade-apply.sh" 2>/dev/null; then
		echo "OK:  A/B marker uses safe misc offset; apply derives mounted root and refuses self-overwrite"
	else
		echo "FAIL: A/B apply must protect the currently mounted root block device" >&2
		missing=1
	fi
	if grep -q 'userdata' "$target/usr/libexec/hmi/ab-upgrade-apply.sh" 2>/dev/null && \
		grep -qE 'refuse|must NOT|ab_refuse' "$target/usr/libexec/hmi/ab-upgrade-apply.sh" 2>/dev/null; then
		echo "OK:  ab-upgrade-apply mentions userdata safety"
	else
		# Soft: apply sources ab-slot-lib refuse helper
		if grep -q 'ab_refuse_userdata_wipe\|userdata' "$target/usr/libexec/hmi/ab-slot-lib.sh" 2>/dev/null; then
			echo "OK:  ab-slot-lib userdata refuse helper present"
		else
			echo "FAIL: A/B helpers missing userdata safety checks" >&2
			missing=1
		fi
	fi
	if grep -qE 'uboot|MiniLoader' "$target/usr/libexec/hmi/ab-upgrade-apply.sh" 2>/dev/null && \
		grep -qiE 'refusing|must not|never' "$target/usr/libexec/hmi/ab-upgrade-apply.sh" 2>/dev/null; then
		echo "OK:  ab-upgrade-apply refuses uboot writes"
	else
		echo "FAIL: ab-upgrade-apply must refuse uboot writes" >&2
		missing=1
	fi
	if grep -q 'enable ab-boot-confirm.service' \
		"$target/etc/systemd/system-preset/99-appliance.preset" 2>/dev/null; then
		echo "OK:  preset enables ab-boot-confirm.service"
	else
		echo "FAIL: preset missing enable ab-boot-confirm.service" >&2
		missing=1
	fi

	if grep -qE 'ListenAddress=0\.0\.0\.0|ListenAddress=\*' \
		"$target/usr/libexec/hmi/lan-ssh-run.sh" 2>/dev/null || \
		grep -qE 'ListenAddress=0\.0\.0\.0|ListenAddress=\*' \
		"$target/etc/systemd/system/ssh-debug-lan.service" 2>/dev/null; then
		echo "FAIL: LAN SSH must not bind 0.0.0.0 (breaks coexistence with USB-SSH)" >&2
		missing=1
	fi
	if grep -q 'WantedBy=' \
		"$target/etc/systemd/system/ssh-debug-lan.service" 2>/dev/null; then
		echo "FAIL: ssh-debug-lan.service must not have [Install] WantedBy" >&2
		missing=1
	else
		echo "OK:  ssh-debug-lan.service has no boot Install"
	fi
	if grep -qiE '^PidFile=' \
		"$target/etc/systemd/system/ssh-debug-lan.service" 2>/dev/null; then
		echo "FAIL: ssh-debug-lan.service must not use PidFile=" >&2
		missing=1
	fi
	if grep -qE 'eth0|wlan0' "$target/usr/libexec/hmi/lan-ssh-run.sh" 2>/dev/null && \
		grep -q 'ListenAddress=' "$target/usr/libexec/hmi/lan-ssh-run.sh" 2>/dev/null && \
		! grep -qE 'ListenAddress=0\.0\.0\.0|ListenAddress=\*' \
			"$target/usr/libexec/hmi/lan-ssh-run.sh" 2>/dev/null; then
		echo "OK:  lan-ssh-run binds eth0/wlan0 only (not 0.0.0.0)"
	else
		echo "FAIL: lan-ssh-run must bind eth0/wlan0 only, not 0.0.0.0" >&2
		missing=1
	fi
	if grep -qE 'systemctl stop.*usb-plug|kill.*usb-plug-sshd|rm -f /run/usb-plug-sshd' \
		"$libexec_hmi/enable-ssh-debug.sh" 2>/dev/null; then
		echo "FAIL: enable-ssh-debug must not stop USB sshd" >&2
		missing=1
	else
		echo "OK:  enable-ssh-debug leaves USB sshd alone"
	fi

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
		# Alias= is only created by systemctl enable; we keep bluetooth boot-deferred,
		# so the overlay must ship dbus-org.bluez.service for D-Bus activation.
		# Use -L/-e carefully: absolute symlinks resolve against the host, not $target.
		alias_unit="$target/etc/systemd/system/dbus-org.bluez.service"
		alias_lib="$target/usr/lib/systemd/system/dbus-org.bluez.service"
		if [[ -L "$alias_unit" || -e "$alias_unit" || -L "$alias_lib" || -e "$alias_lib" ]]; then
			echo "OK:  dbus-org.bluez.service alias"
		else
			echo "FAIL: dbus-org.bluez.service alias missing (D-Bus cannot restart bluetoothd)" >&2
			missing=1
		fi
		if grep -q 'Restart=on-abnormal' \
			"$target/etc/systemd/system/bluetooth.service.d/appliance.conf" 2>/dev/null; then
			echo "OK:  bluetooth.service Restart=on-abnormal"
		else
			echo "FAIL: bluetooth.service.d missing Restart=on-abnormal" >&2
			missing=1
		fi
		if [[ -e "$target/etc/systemd/system/bt-hid-heal.service" ]] || \
			[[ -e "$target/usr/lib/systemd/system/bt-hid-heal.service" ]]; then
			echo "FAIL: bt-hid-heal.service must be retired (HAL in-process heal)" >&2
			missing=1
		else
			echo "OK:  bt-hid-heal.service absent"
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
