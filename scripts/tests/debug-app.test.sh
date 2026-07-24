#!/usr/bin/env bash
# Host-side static checks for debug-app tooling.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail=0

assert_file() {
	local path="$1"
	if [[ -f "$path" ]]; then
		echo "OK  $path"
	else
		echo "FAIL missing $path" >&2
		fail=1
	fi
}

assert_executable() {
	local path="$1"
	if [[ -x "$path" ]]; then
		echo "OK  $path"
	else
		echo "FAIL not executable $path" >&2
		fail=1
	fi
}

assert_file "$ROOT/overlay/buildroot/flutterpi_tool.version"
assert_executable "$ROOT/scripts/build-debug-app.sh"
assert_executable "$ROOT/scripts/debug-app.sh"
assert_executable "$ROOT/scripts/debug-setup.sh"
assert_executable "$ROOT/scripts/debug-app-deploy.sh"
assert_executable "$ROOT/scripts/debug-custom-device/install.sh"
assert_executable "$ROOT/scripts/debug-custom-device/forward-port.sh"
assert_executable "$ROOT/overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/usr/libexec/hmi/hmi-launch.sh"
assert_executable "$ROOT/overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/usr/libexec/hmi/hmi-stop-and-wait.sh"
assert_executable "$ROOT/overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/usr/libexec/hmi/debug-app-apply.sh"
assert_executable "$ROOT/overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/usr/libexec/hmi/debug-app-run.sh"

if grep -q '"--no-track-widget-creation"' "$ROOT/.vscode/launch.json" \
	&& grep -q '"dart.flutterRunAdditionalArgs".*"--no-track-widget-creation"' "$ROOT/.vscode/settings.json" \
	&& grep -q -- '--no-track-widget-creation' "$ROOT/scripts/debug-app.sh"; then
	echo "OK  all IDE and CLI launches match flutterpi_tool widget tracking"
else
	echo "FAIL an IDE or CLI launch can differ from initial bundle widget tracking" >&2
	fail=1
fi

if ! grep -q 'hmi-launch.sh' "$ROOT/overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/etc/systemd/system/hmi.service"; then
	echo "FAIL hmi.service does not use hmi-launch.sh" >&2
	fail=1
else
	echo "OK  hmi.service uses hmi-launch.sh"
fi

if grep -q 'make emulator' "$ROOT/Makefile"; then
	echo "FAIL Makefile introduces make emulator" >&2
	fail=1
else
	echo "OK  no make emulator target"
fi

if grep -q 'exec usb_ssh_session_' "$ROOT/scripts/debug-custom-device/run-debug.sh"; then
	echo "FAIL run-debug.sh tries to exec a shell function" >&2
	fail=1
else
	echo "OK  run-debug.sh invokes sourced SSH helper"
fi

assert_executable "$ROOT/scripts/debug-host-prepare.sh"
assert_executable "$ROOT/scripts/device-target.sh"
assert_executable "$ROOT/scripts/ssh-devices.sh"

if grep -q 'usb_ssh_session_try_select' "$ROOT/scripts/usb-ssh-session.sh" \
	&& grep -q 'usb_ssh_session_try_select' "$ROOT/scripts/debug-host-prepare.sh"; then
	echo "OK  debug-host-prepare soft-selects without silent exit"
else
	echo "FAIL debug-host-prepare can still exit silently on empty devices" >&2
	fail=1
fi

if grep -q 'debug-host-prepare.sh' "$ROOT/scripts/debug-app.sh" \
	&& ! grep -q 'usb-ssh-host-setup.sh' "$ROOT/scripts/debug-app.sh"; then
	echo "OK  debug-app uses debug-host-prepare (not forced USB ECM)"
else
	echo "FAIL debug-app still forces USB host setup" >&2
	fail=1
fi

# TSV is MODE SN ChipID LocationID IFACE IP USB — must not treat ChipID as IFACE.
if grep -qE 'read -r _mode _serial _chip _loc iface' "$ROOT/scripts/usb-ssh-host-setup.sh"; then
	echo "OK  usb-ssh-host-setup parses ChipID column"
else
	echo "FAIL usb-ssh-host-setup TSV parse missing ChipID (breaks make debug-app)" >&2
	fail=1
fi

# Default Weston image is AOT-only; debug-app must refuse before overwriting /opt/hmi.
if grep -q 'display-stack' "$ROOT/scripts/debug-app-deploy.sh" \
	&& grep -q 'flutter-pi only' "$ROOT/scripts/debug-app-deploy.sh" \
	&& grep -q 'refusing debug install on display-stack' \
		"$ROOT/overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/usr/libexec/hmi/debug-app-apply.sh"; then
	echo "OK  debug-app refuses Weston before blanking /opt/hmi"
else
	echo "FAIL debug-app missing Weston display-stack guard" >&2
	fail=1
fi

if grep -q 'make debug-host-prepare debug-setup build-debug-app' "$ROOT/.vscode/tasks.json" \
	&& ! grep -q 'make usb-ssh-setup debug-setup build-debug-app' "$ROOT/.vscode/tasks.json"; then
	echo "OK  IDE preLaunchTask uses debug-host-prepare"
else
	echo "FAIL IDE preLaunchTask still forces usb-ssh-setup" >&2
	fail=1
fi

if grep -q 'USB-SSH / SSH' "$ROOT/scripts/debug-setup.sh" \
	&& grep -q 'USB-SSH / SSH' "$ROOT/.vscode/launch.json"; then
	echo "OK  custom-device / launch labels mention SSH"
else
	echo "FAIL debug device labels still USB-SSH-only" >&2
	fail=1
fi

if grep -q 'usb_ssh_session_is_remote' "$ROOT/scripts/debug-custom-device/ping.sh" \
	&& grep -q 'ping_remote_ssh_target' "$ROOT/scripts/debug-custom-device/ping.sh" \
	&& grep -q 'usb_ssh_session_is_remote' "$ROOT/scripts/debug-custom-device/forward-port.sh"; then
	echo "OK  custom-device ping/forward handle remote SSH"
else
	echo "FAIL custom-device adapters missing remote SSH branches" >&2
	fail=1
fi

if grep -q '^local .*ssh_opts' "$ROOT/scripts/debug-custom-device/forward-port.sh"; then
	echo "FAIL forward-port.sh uses local outside a function" >&2
	fail=1
else
	echo "OK  forward-port.sh declares options at script scope"
fi

if grep -q 'SSH SCP connection failed; retrying' "$ROOT/scripts/usb-ssh-session.sh"; then
	echo "OK  SSH SCP retries transient connection failures"
else
	echo "FAIL SSH SCP has no transient connection retry" >&2
	fail=1
fi

if grep -q 'Dart VM service is listening on' \
	"$ROOT/overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/usr/libexec/hmi/debug-app-run.sh"; then
	echo "OK  debug-app-run matches Flutter 3.24 VM Service output"
else
	echo "FAIL debug-app-run misses Flutter 3.24 VM Service output" >&2
	fail=1
fi

if grep -q 'start-stop-daemon -S -b -m' \
	"$ROOT/overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/usr/libexec/hmi/debug-app-run.sh" \
	&& grep -q 'live_flutter_pids' \
	"$ROOT/overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/usr/libexec/hmi/hmi-stop-and-wait.sh"; then
	echo "OK  debug process detaches cleanly and ignores zombies"
else
	echo "FAIL debug process lifecycle can retain flutter-pi zombies" >&2
	fail=1
fi

if bash "$ROOT/scripts/build-debug-app.sh" >/tmp/hmi-build-debug-app.log 2>&1; then
	echo "OK  build-debug-app"
	assert_file "$ROOT/.cache/debug-app-staging/opt/hmi/data/flutter_assets/kernel_blob.bin"
	assert_file "$ROOT/.cache/debug-app-staging/debug-runtime/3.24.4/manifest.json"
else
	echo "FAIL build-debug-app (see /tmp/hmi-build-debug-app.log)" >&2
	fail=1
fi

if bash "$ROOT/scripts/debug-setup.sh" >/tmp/hmi-debug-setup.log 2>&1; then
	echo "OK  debug-setup"
else
	echo "FAIL debug-setup (see /tmp/hmi-debug-setup.log)" >&2
	fail=1
fi

exit "$fail"
