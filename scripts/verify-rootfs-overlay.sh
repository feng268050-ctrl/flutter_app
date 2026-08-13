#!/usr/bin/env bash
# After build-rootfs: confirm overlay files in target/ and Plan A systemd in rootfs.ext2.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${SDK_DIR:-$ROOT/linux-sdk}"
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
	if [[ -x "$root/usr/libexec/power/pre-poweroff.sh" && \
		-x "$root/usr/libexec/power/shutdown.sh" && \
		-x "$root/usr/libexec/power/systemctl-poweroff-wrapper.sh" ]]; then
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
		../libexec/power/systemctl-poweroff-wrapper.sh) ;;
		/usr/libexec/power/systemctl-poweroff-wrapper.sh) ;;
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
	local libexec_board="$target/usr/libexec/board"
	local libexec_usb="$target/usr/libexec/usb"
	local libexec_ab="$target/usr/libexec/ab"
	local libexec_oem="$target/usr/libexec/oem"
	local libexec_display="$target/usr/libexec/display"
	local libexec_power="$target/usr/libexec/power"
	local libexec_ssh="$target/usr/libexec/ssh"
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

	for tier in "$libexec_hmi" "$libexec_board" "$libexec_usb" "$libexec_ab" "$libexec_oem" \
		"$libexec_display" "$libexec_power" "$libexec_ssh" "$libexec_wpa" "$libexec_net" "$libexec_bt"; do
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
		grep -q '/usr/libexec/board/serial-console-stty.sh' \
		"$target/etc/profile.d/serial-stty.sh" 2>/dev/null; then
		echo "OK:  profile.d/serial-stty.sh uses /usr/libexec/board/"
	else
		echo "FAIL: profile.d/serial-stty.sh missing or not pointing at /usr/libexec/board/serial-console-stty.sh" >&2
		missing=1
	fi

	echo ""
	echo "--- usr/libexec/hmi (App/UI only) ---"
	for f in hmi-launch.sh hmi-stop-and-wait.sh restart-flutter-seat.sh \
		debug-app-apply.sh debug-app-run.sh debug-runtime-install.sh \
		diagnose-hmi.sh extract-video-frame; do
		if [[ -x "$libexec_hmi/$f" ]]; then
			echo "OK:  hmi/$f"
		else
			echo "FAIL: hmi/$f missing or not executable" >&2
			missing=1
		fi
	done
	for stale in push-app-apply-and-restart.sh upgrade-app-apply-and-restart.sh; do
		if [[ -e "$libexec_hmi/$stale" ]]; then
			echo "FAIL: removed helper still under hmi/$stale (App owns install+restart)" >&2
			missing=1
		fi
	done
	for stale in read-device-serial.sh read-product-identity.sh write-product-identity.sh \
		vendor-storage-ids.txt secrets-seal secrets-seal-ca paths.sh lws-hostname.sh \
		device-mdns-advertise.sh serial-console-stty.sh reboot-loader boot-verify.sh env-verify.sh \
		usb-otg-mode.sh usb-gadget-usb-state.sh usb-plug-ssh-start.sh usb-plug-ssh-stop.sh \
		usb-plug-ssh-recover.sh usb-plug-ssh-diag.sh usb-plug-ssh-vbus-check.sh \
		usb-mtp-start.sh usb-mtp-stop.sh ab-slot-lib.sh ab-upgrade-apply.sh ab-upgrade-stream.sh ab-ota-verify.sh \
		ab-preflight.sh ab-boot-confirm.sh oem-compose.sh ynh960-display-init.sh weston-hmi-config.sh \
		change-orientation.sh apply-wallpaper.sh apply-mouse-settings.sh set-performance-mode.sh bind-prefs.sh \
		pre-poweroff.sh shutdown.sh pwrkey-poweroff.sh systemctl-poweroff-wrapper.sh \
		enable-ssh-debug.sh disable-ssh-debug.sh lan-ssh-run.sh ensure-sshd-hostkeys.sh; do
		if [[ -e "$libexec_hmi/$stale" ]]; then
			echo "FAIL: moved helper still under hmi/$stale" >&2
			missing=1
		fi
	done

	echo ""
	echo "--- usr/libexec/board ---"
	for f in read-device-serial.sh read-product-identity.sh write-product-identity.sh \
		read-cloud-ed25519-sealed.sh write-cloud-ed25519-sealed.sh \
		secrets-seal secrets-seal-ca paths.sh lws-hostname.sh device-mdns-advertise.sh \
		serial-console-stty.sh reboot-loader boot-verify.sh env-verify.sh \
		set-performance-mode.sh bind-prefs.sh apply-datetime-prefs.sh provision-mount.sh factory-reset.sh emulator-storage-init.sh; do
		if [[ -x "$libexec_board/$f" ]] || [[ -f "$libexec_board/$f" && "$f" == paths.sh ]]; then
			echo "OK:  board/$f"
		else
			echo "FAIL: board/$f missing or not executable" >&2
			missing=1
		fi
	done
	if [[ -f "$libexec_board/vendor-storage-ids.txt" ]]; then
		echo "OK:  board/vendor-storage-ids.txt"
		if grep -q 'VENDOR_CLOUD_ED25519_ID=22' "$libexec_board/vendor-storage-ids.txt" \
			&& grep -q 'VENDOR_CLOUD_ED25519_NAME=VENDOR_CUSTOM_ID_16' \
				"$libexec_board/vendor-storage-ids.txt"; then
			echo "OK:  board/vendor-storage-ids.txt cloud Ed25519 ID 22"
		else
			echo "FAIL: board/vendor-storage-ids.txt missing cloud Ed25519 ID 22" >&2
			missing=1
		fi
	else
		echo "FAIL: board/vendor-storage-ids.txt missing" >&2
		missing=1
	fi

	echo ""
	echo "--- usr/libexec/usb ---"
	for f in usb-otg-mode.sh usb-gadget-usb-state.sh usb-plug-ssh-start.sh usb-plug-ssh-stop.sh \
		usb-plug-ssh-recover.sh usb-plug-ssh-diag.sh usb-plug-ssh-vbus-check.sh \
		usb-mtp-start.sh usb-mtp-stop.sh; do
		if [[ -x "$libexec_usb/$f" ]]; then
			echo "OK:  usb/$f"
		else
			echo "FAIL: usb/$f missing or not executable" >&2
			missing=1
		fi
	done

	echo ""
	echo "--- usr/libexec/ab ---"
	for f in ab-slot-lib.sh ab-preflight.sh ab-boot-confirm.sh; do
		if [[ -x "$libexec_ab/$f" ]] || [[ -f "$libexec_ab/$f" && "$f" == ab-slot-lib.sh ]]; then
			echo "OK:  ab/$f"
		else
			echo "FAIL: ab/$f missing or not executable" >&2
			missing=1
		fi
	done
	for retired in ab-upgrade-apply.sh ab-upgrade-stream.sh ab-ota-verify.sh; do
		if [[ -e "$libexec_ab/$retired" ]]; then
			echo "FAIL: retired ab/$retired still present (OTA is packages/cyber_ota)" >&2
			missing=1
		else
			echo "OK:  retired ab/$retired absent"
		fi
	done

	echo ""
	echo "--- usr/libexec/oem ---"
	if [[ -x "$libexec_oem/oem-compose.sh" ]]; then
		echo "OK:  oem/oem-compose.sh"
	else
		echo "FAIL: oem/oem-compose.sh missing or not executable" >&2
		missing=1
	fi

	echo ""
	echo "--- oem screen pack default_ui_scale ---"
	check_screen_default_ui_scale() {
		local json="$1" expected="$2" label="$3"
		local got
		got="$(sed -n 's/.*"default_ui_scale"[[:space:]]*:[[:space:]]*\([0-9.][0-9.]*\).*/\1/p' "$json" | head -1)"
		if [[ "$got" == "$expected" ]]; then
			echo "OK:  $label default_ui_scale=$got"
		else
			echo "FAIL: $label default_ui_scale=$got (expected $expected) in $json" >&2
			missing=1
		fi
	}
	check_screen_default_ui_scale \
		"$ROOT/oem/screens/panel-ynh960-800x1280/screen.json" "1.13" "ynh960 panel"
	check_screen_default_ui_scale \
		"$ROOT/oem/screens/virt/screen.json" "1.28" "virt"

	echo ""
	echo "--- usr/libexec/display ---"
	for f in ynh960-display-init.sh weston-hmi-config.sh change-orientation.sh apply-wallpaper.sh \
		apply-mouse-settings.sh; do
		if [[ -x "$libexec_display/$f" ]]; then
			echo "OK:  display/$f"
		else
			echo "FAIL: display/$f missing or not executable" >&2
			missing=1
		fi
	done

	echo ""
	echo "--- usr/libexec/power ---"
	for f in pre-poweroff.sh shutdown.sh pwrkey-poweroff.sh systemctl-poweroff-wrapper.sh; do
		if [[ -x "$libexec_power/$f" ]]; then
			echo "OK:  power/$f"
		else
			echo "FAIL: power/$f missing or not executable" >&2
			missing=1
		fi
	done

	echo ""
	echo "--- usr/libexec/ssh ---"
	for f in enable-ssh-debug.sh disable-ssh-debug.sh lan-ssh-run.sh ensure-sshd-hostkeys.sh; do
		if [[ -x "$libexec_ssh/$f" ]]; then
			echo "OK:  ssh/$f"
		else
			echo "FAIL: ssh/$f missing or not executable" >&2
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
	if [[ -x "$target/usr/bin/curl" ]] || [[ -x "$target/bin/curl" ]]; then
		echo "OK:  curl present"
	else
		echo "FAIL: curl missing — enable BR2_PACKAGE_LIBCURL + BR2_PACKAGE_LIBCURL_CURL" >&2
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
verify-boot /usr/libexec/board/boot-verify.sh
verify-env /usr/libexec/board/env-verify.sh
diagnose-hmi /usr/libexec/hmi/diagnose-hmi.sh
diagnose-usb-ssh /usr/libexec/usb/usb-plug-ssh-diag.sh
read-serial /usr/libexec/board/read-device-serial.sh
read-identity /usr/libexec/board/read-product-identity.sh
write-identity /usr/libexec/board/write-product-identity.sh
read-cloud-ed25519-sealed /usr/libexec/board/read-cloud-ed25519-sealed.sh
write-cloud-ed25519-sealed /usr/libexec/board/write-cloud-ed25519-sealed.sh
start-usb-ssh /usr/libexec/usb/usb-plug-ssh-start.sh
stop-usb-ssh /usr/libexec/usb/usb-plug-ssh-stop.sh
recover-usb-ssh /usr/libexec/usb/usb-plug-ssh-recover.sh
reboot-loader /usr/libexec/board/reboot-loader
change-orientation /usr/libexec/display/change-orientation.sh
apply-wallpaper /usr/libexec/display/apply-wallpaper.sh
enable-ssh-debug /usr/libexec/ssh/enable-ssh-debug.sh
disable-ssh-debug /usr/libexec/ssh/disable-ssh-debug.sh
usb-otg-mode /usr/libexec/usb/usb-otg-mode.sh
set-performance-mode /usr/libexec/board/set-performance-mode.sh
set-power-mode /usr/libexec/board/set-performance-mode.sh
apply-mouse-settings /usr/libexec/display/apply-mouse-settings.sh
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
	if [[ ! -f "$target/usr/share/hal/wallpapers/home_back.png" ]]; then
		echo "FAIL: usr/share/hal/wallpapers/home_back.png missing (system wallpaper preset)" >&2
		fail=1
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
	if grep -q 'ListenAddress=192.168.55.1' "$libexec_usb/usb-plug-ssh-start.sh" 2>/dev/null; then
		echo "OK:  usb-plug-ssh-start binds ListenAddress=192.168.55.1"
	else
		echo "FAIL: usb-plug-ssh-start missing ListenAddress=192.168.55.1 override" >&2
		missing=1
	fi
	if grep -q 'skip USB-only sshd' "$libexec_usb/usb-plug-ssh-start.sh" 2>/dev/null; then
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
	if grep -q 'modprobe g_ether' "$libexec_usb/usb-plug-ssh-start.sh" 2>/dev/null && \
		! grep -q '/sys/kernel/config/usb_gadget/lws_hmi' "$libexec_usb/usb-plug-ssh-start.sh" 2>/dev/null; then
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
	if [[ -f "$target/usr/lib/libhmi_capture.so" ]]; then
		echo "OK:  usr/lib/libhmi_capture.so present"
	else
		echo "FAIL: usr/lib/libhmi_capture.so missing (make build-hmi-capture)" >&2
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

	# Optional second Flutter app (os_settings) when source tree exists.
	if [[ -f "$ROOT/app/os_settings/pubspec.yaml" ]]; then
		echo ""
		echo "--- /opt/os_settings (optional Flutter app — no engine) ---"
		for f in \
			"$target/opt/os_settings/lib/libapp.so" \
			"$target/opt/os_settings/data/flutter_assets/AssetManifest.bin"; do
			if [[ -e "$f" ]]; then
				echo "OK:  ${f#$target/}"
			else
				echo "FAIL: missing ${f#$target/} (app/os_settings present; run: make build-rootfs)" >&2
				missing=1
			fi
		done
		if [[ -f "$target/opt/os_settings/lib/libflutter_engine.so" ]]; then
			echo "FAIL: opt/os_settings/lib/libflutter_engine.so present (engine belongs in /usr/lib only)" >&2
			missing=1
		else
			echo "OK:  opt/os_settings/lib/libflutter_engine.so absent (system engine)"
		fi
		if [[ -f "$target/opt/os_settings/data/icudtl.dat" ]]; then
			echo "FAIL: opt/os_settings/data/icudtl.dat present (use /usr/share/flutter on rootfs)" >&2
			missing=1
		else
			echo "OK:  opt/os_settings/data/icudtl.dat absent (system icu)"
		fi
		for jit in kernel_blob.bin isolate_snapshot_data vm_snapshot_data; do
			if [[ -f "$target/opt/os_settings/data/flutter_assets/$jit" ]]; then
				echo "FAIL: opt/os_settings/data/flutter_assets/$jit present (release AOT only)" >&2
				missing=1
			else
				echo "OK:  opt/os_settings/data/flutter_assets/$jit absent (no JIT)"
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
	if [[ -f "$target/etc/hmi/usb-otg.ini" ]]; then
		echo "FAIL: retired /etc/hmi/usb-otg.ini must not ship (use /etc/usb-otg.ini)" >&2
		missing=1
	elif [[ ! -f "$target/etc/usb-otg.ini" ]]; then
		echo "FAIL: /etc/usb-otg.ini missing" >&2
		missing=1
	else
		echo "OK:  usb-otg policy at /etc/usb-otg.ini (no /etc/hmi/usb-otg.ini)"
	fi
	if [[ -f "$target/etc/hmi/flutter-engine.version" ]]; then
		echo "FAIL: retired /etc/hmi/flutter-engine.version must not ship (use /usr/share/flutter/flutter-engine.version)" >&2
		missing=1
	elif [[ ! -f "$target/usr/share/flutter/flutter-engine.version" ]]; then
		echo "FAIL: /usr/share/flutter/flutter-engine.version missing" >&2
		missing=1
	else
		echo "OK:  flutter-engine.version at /usr/share/flutter/ (no /etc/hmi stamp)"
	fi
	br_pin="$ROOT/overlay/buildroot/BUILDROOT_VERSION"
	br_stamp="$target/usr/share/buildroot/BUILDROOT_VERSION"
	if [[ ! -f "$br_pin" ]]; then
		echo "FAIL: missing git pin $br_pin" >&2
		missing=1
	elif [[ ! -f "$br_stamp" ]]; then
		echo "FAIL: /usr/share/buildroot/BUILDROOT_VERSION missing (post-build sync-buildroot-version)" >&2
		missing=1
	else
		pin_ver="$(tr -d '[:space:]' <"$br_pin")"
		stamp_ver="$(tr -d '[:space:]' <"$br_stamp")"
		if [[ -z "$pin_ver" || "$pin_ver" != "$stamp_ver" ]]; then
			echo "FAIL: BUILDROOT_VERSION stamp ($stamp_ver) != pin ($pin_ver)" >&2
			missing=1
		else
			echo "OK:  Buildroot pin at /usr/share/buildroot/BUILDROOT_VERSION ($stamp_ver)"
		fi
	fi
	if [[ "$has_weston" -eq 1 ]]; then
		echo "OK:  weston image (flutter-wayland-client)"
		# Unpatched GStreamer video plugin SIGSEGVs on live RTSP initialize.
		# Prefer grep -a over `strings | grep` (pipefail + early match → SIGPIPE 141
		# false-FAIL). Same helper pattern as scripts/check-prebuilt.sh.
		vp="$target/usr/lib/libvideo_player_plugin.so"
		_vp_has() { grep -a -F -q -- "$2" "$1" 2>/dev/null; }
		if [[ -f "$vp" ]]; then
			if ! _vp_has "$vp" 'Video size unknown after preroll'; then
				echo "FAIL: $vp missing live-RTSP patch (will segfault in IP Camera)" >&2
				missing=1
			elif ! _vp_has "$vp" 'MppElementSetup: mppvideodec format=RGBA'; then
				echo "FAIL: $vp missing MPP RGBA patch" >&2
				echo "  Run: FORCE=1 make rebuild-flutter-embedded-linux" >&2
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

	if [[ -x "$target/usr/libexec/ssh/enable-ssh-debug.sh" && -x "$target/usr/libexec/ssh/disable-ssh-debug.sh" ]]; then
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
	if [[ -x "$libexec_board/bind-prefs.sh" ]] && \
		( grep -q 'bind-prefs.sh' \
			"$libexec_display/ynh960-display-init.sh" 2>/dev/null || \
		  grep -q 'bind-prefs.sh' \
			"$ROOT/oem/boards/ynh960/helpers/display-init.sh" 2>/dev/null ); then
		echo "OK:  bind-prefs (four /var/lib/* → /userdata/*)"
	else
		echo "FAIL: missing bind-prefs.sh wired into display-init (stub or OEM helper)" >&2
		missing=1
	fi
	if [[ -x "$libexec_board/provision-mount.sh" ]] && \
		( grep -q 'provision-mount.sh' \
			"$ROOT/oem/boards/ynh960/helpers/display-init.sh" 2>/dev/null || \
		  grep -q 'provision-mount.sh' \
			"$libexec_board/emulator-storage-init.sh" 2>/dev/null ); then
		echo "OK:  provision-mount (properties.ini → /mnt/provision)"
	else
		echo "FAIL: missing provision-mount.sh wired into display-init or emulator-storage-init" >&2
		missing=1
	fi
	if [[ -x "$libexec_board/apply-datetime-prefs.sh" ]] && \
		( grep -q 'apply-datetime-prefs.sh' \
			"$ROOT/oem/boards/ynh960/helpers/display-init.sh" 2>/dev/null || \
		  grep -q 'apply-datetime-prefs.sh' \
			"$libexec_board/emulator-storage-init.sh" 2>/dev/null ) && \
		grep -q 'apply-datetime-prefs.sh' \
			"$ROOT/overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/usr/libexec/hmi/hmi-launch.sh" 2>/dev/null; then
		echo "OK:  apply-datetime-prefs (datetime.conf → /etc/localtime)"
	else
		echo "FAIL: missing apply-datetime-prefs.sh wired into display-init, emulator-storage-init, or hmi-launch" >&2
		missing=1
	fi
	if [[ -x "$libexec_board/factory-reset.sh" ]] && [[ -L "$target/usr/bin/factory-reset" ]]; then
		echo "OK:  factory-reset helper + /usr/bin/factory-reset"
	else
		echo "FAIL: missing factory-reset.sh or /usr/bin/factory-reset symlink" >&2
		missing=1
	fi
	if [[ -f "$target/etc/systemd/system/emulator-storage-init.service" ]] && \
		grep -q 'enable emulator-storage-init.service' \
			"$target/etc/systemd/system-preset/99-appliance.preset" 2>/dev/null; then
		echo "OK:  emulator-storage-init preset (QEMU provision + bind-prefs)"
	else
		echo "FAIL: missing emulator-storage-init.service preset" >&2
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
	if [[ -x "$target/usr/libexec/ssh/lan-ssh-run.sh" ]]; then
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
	echo "--- A/B upgrade helpers (P2.4 / P4.8) ---"
	for f in \
		"$target/usr/libexec/ab/ab-slot-lib.sh" \
		"$target/usr/libexec/ab/ab-preflight.sh" \
		"$target/usr/libexec/ab/ab-boot-confirm.sh" \
		"$target/etc/systemd/system/ab-boot-confirm.service"; do
		if [[ -e "$f" ]]; then
			echo "OK:  ${f#$target/}"
		else
			echo "FAIL: missing ${f#$target/}" >&2
			missing=1
		fi
	done
	for retired in \
		"$target/usr/libexec/ab/ab-upgrade-apply.sh" \
		"$target/usr/libexec/ab/ab-upgrade-stream.sh" \
		"$target/usr/libexec/ab/ab-ota-verify.sh" \
		"$target/usr/libexec/hmi/ab-upgrade-app-only.sh"; do
		if [[ -e "$retired" ]]; then
			echo "FAIL: retired ${retired#$target/} still present" >&2
			missing=1
		else
			echo "OK:  retired ${retired#$target/} absent"
		fi
	done
	if grep -q 'ab_current_root_dev' "$target/usr/libexec/ab/ab-slot-lib.sh" 2>/dev/null && \
		grep -q '^AB_MISC_OFFSET=1048576$' "$target/usr/libexec/ab/ab-slot-lib.sh" 2>/dev/null && \
		grep -q 'ab_slot_marker_valid' "$target/usr/libexec/ab/ab-slot-lib.sh" 2>/dev/null && \
		grep -q 'ab_same_block_device' "$target/usr/libexec/ab/ab-slot-lib.sh" 2>/dev/null && \
		grep -q 'ab_refuse_userdata_wipe\|userdata' "$target/usr/libexec/ab/ab-slot-lib.sh" 2>/dev/null; then
		echo "OK:  A/B slot-lib uses safe misc offset + mounted-root / userdata helpers"
	else
		echo "FAIL: ab-slot-lib missing A/B safety helpers" >&2
		missing=1
	fi
	if grep -q 'ab_current_root_letter' "$target/usr/libexec/ab/ab-preflight.sh" 2>/dev/null && \
		grep -q 'fit_name=' "$target/usr/libexec/ab/ab-preflight.sh" 2>/dev/null; then
		echo "OK:  ab-preflight.sh prints host KEY=VALUE preflight"
	else
		echo "FAIL: ab-preflight.sh missing preflight contract" >&2
		missing=1
	fi
	if [[ -f "$target/etc/ota/ed25519.pub" ]]; then
		echo "OK:  /etc/ota/ed25519.pub present"
	else
		echo "FAIL: missing /etc/ota/ed25519.pub (cloud OTA pubkey)" >&2
		missing=1
	fi
	if [[ -e "$target/etc/ota/ed25519.pem" ]] || [[ -e "$target/etc/ota/ed25519.key" ]]; then
		echo "FAIL: OTA private key must not be in rootfs under /etc/ota/" >&2
		missing=1
	else
		echo "OK:  no OTA private key under /etc/ota/"
	fi
	# openssl CLI is Buildroot-installed (not in fs-overlay). When verifying a
	# full target root (BR output), require it; overlay-only checks skip.
	if [[ -x "$target/usr/bin/openssl" ]]; then
		echo "OK:  /usr/bin/openssl present (OTA verify via cyber_ota)"
	elif [[ -d "$target/usr/libexec/ab" ]] && \
		[[ ! -x "$target/usr/bin/systemctl" && ! -x "$target/bin/systemctl" ]]; then
		echo "OK:  openssl CLI deferred (fs-overlay check; ensure BR2_PACKAGE_LIBOPENSSL_BIN in rootfs)"
	else
		echo "FAIL: missing /usr/bin/openssl (enable BR2_PACKAGE_LIBOPENSSL_BIN; dirclean rebuild libopenssl)" >&2
		missing=1
	fi
	if [[ -f "$target/etc/os-release" ]] && \
		grep -q '^ID=cyberos$' "$target/etc/os-release" && \
		grep -q '^NAME="Cyber OS"$' "$target/etc/os-release"; then
		echo "OK:  /etc/os-release is Cyber OS"
	else
		echo "FAIL: /etc/os-release must identify Cyber OS (NAME/ID)" >&2
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
		"$target/usr/libexec/ssh/lan-ssh-run.sh" 2>/dev/null || \
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
	if grep -qE 'eth0|wlan0' "$target/usr/libexec/ssh/lan-ssh-run.sh" 2>/dev/null && \
		grep -q 'ListenAddress=' "$target/usr/libexec/ssh/lan-ssh-run.sh" 2>/dev/null && \
		! grep -qE 'ListenAddress=0\.0\.0\.0|ListenAddress=\*' \
			"$target/usr/libexec/ssh/lan-ssh-run.sh" 2>/dev/null; then
		echo "OK:  lan-ssh-run binds eth0/wlan0 only (not 0.0.0.0)"
	else
		echo "FAIL: lan-ssh-run must bind eth0/wlan0 only, not 0.0.0.0" >&2
		missing=1
	fi
	if grep -qE 'systemctl stop.*usb-plug|kill.*usb-plug-sshd|rm -f /run/usb-plug-sshd' \
		"$libexec_ssh/enable-ssh-debug.sh" 2>/dev/null; then
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
			echo "FAIL: bluetoothd missing (BlueZ installs to usr/libexec/bluetooth/)" >&2
			echo "  Run: bash scripts/br-make-packages.sh bluez bluez5_utils bluez5_utils-headers bluez-alsa && make build-rootfs" >&2
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
		if [[ -e "$target/usr/libexec/bluetooth/obexd" ]]; then
			echo "FAIL: obexd present (OBEX disabled; purge-retired should remove)" >&2
			missing=1
		else
			echo "OK:  obexd absent (H1)"
		fi
		if command -v strings >/dev/null 2>&1; then
			bt_ver="$(strings "$target/usr/libexec/bluetooth/bluetoothd" 2>/dev/null \
				| grep -E '^[0-9]+\.[0-9]+$' | sort -u | tr '\n' ' ')"
			case " $bt_ver " in
			*" 5.87 "*|*" 5.88 "*|*" 5.89 "*)
				echo "OK:  bluetoothd version string includes ≥5.87 ($bt_ver)"
				;;
			*)
				# Cross-binaries may not expose a clean version via strings on all hosts.
				echo "WARN: bluetoothd version strings unclear ($bt_ver) — confirm on device with bluetoothd -v"
				;;
			esac
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
	if grep -qF '#include "chips/lws_hmi_font.config"' "$def" 2>/dev/null; then
		echo ""
		echo "--- CJK fonts (lws_hmi_font.config) ---"
		local han_dir="$target/usr/share/fonts/source-han-sans-cn"
		local han_otf
		if [[ ! -d "$han_dir" ]]; then
			echo "FAIL: $han_dir missing (Source Han Sans CN; CJK will tofu). Fix: apply-overlay must wire package/source-han-sans into package/Config.in, then: bash scripts/br-make-packages.sh fonts source-han-sans-cn && make build-rootfs" >&2
			missing=1
		else
			for han_otf in SourceHanSansCN-Regular.otf SourceHanSansCN-Medium.otf SourceHanSansCN-Bold.otf; do
				if [[ -f "$han_dir/$han_otf" ]]; then
					echo "OK:  fonts/source-han-sans-cn/$han_otf"
				else
					echo "FAIL: fonts/source-han-sans-cn/$han_otf missing" >&2
					missing=1
				fi
			done
		fi
		if [[ ! -d "$target/usr/share/fonts/dejavu" ]]; then
			echo "FAIL: fonts/dejavu missing" >&2
			missing=1
		else
			echo "OK:  fonts/dejavu"
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
	run_check "$(resolve_br_target "${SDK_DIR:-/work/sdk}")"
	exit $?
fi

if [[ -z "$SDK" || ! -d "$SDK" ]]; then
	echo "ERROR: SDK not found at $SDK. Copy it to repo-root linux-sdk/." >&2
	exit 1
fi

run_check "$(resolve_br_target "$SDK")"
