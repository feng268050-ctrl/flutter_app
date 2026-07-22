#!/usr/bin/env bash
# Trigger a demo alarm popup on a connected board (USB-SSH / registered SSH).
# App watches /run/hmi/demo-alarm.cmd (see DemoAlarmCommandWatcher).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"

CMD_PATH="/run/hmi/demo-alarm.cmd"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

usage() {
	cat <<'EOF'
Usage:
  make alarm CODE=<ALARM_CODE>
  make alarm-clean

Examples:
  make alarm CODE=E006
  make alarm CODE=L001
  make alarm CODE=C002
  make alarm CODE=H034
  SN=<sn> make alarm CODE=H001
  make alarm-clean

CODE must exist in ProductAlarmCatalog (lws-ui AlarmCodeEnums parity, including
non-Modbus codes such as L001 / C002 / H034). HMI must be running (hmi.service).
EOF
}

remote() {
	usb_ssh_session_run_ssh "$ROOT" "$IFACE" "$@"
}

write_cmd() {
	local line="$1"
	# CODE is validated to [A-Za-z][A-Za-z0-9]*; clean has no args.
	remote "mkdir -p /run/hmi && printf '%s\n' '${line}' > '${CMD_PATH}.tmp' && mv -f '${CMD_PATH}.tmp' '${CMD_PATH}'"
}

trigger() {
	local code="${1:-${CODE:-}}"
	[[ -n "$code" ]] || die "CODE is required (example: make alarm CODE=E006)"
	[[ "$code" =~ ^[A-Za-z][A-Za-z0-9]*$ ]] || die "invalid CODE: $code"
	write_cmd "trigger ${code}"
	echo "OK: demo alarm command sent for code=${code}"
	echo "INFO: filter journal with: make logs GREP=WARN_DBG"
}

clean() {
	write_cmd "clean"
	echo "OK: alarm restrictions clean command sent (visible popup unchanged)"
	echo "INFO: filter journal with: make logs GREP=WARN_DBG"
}

main() {
	usb_ssh_session_load_env "$ROOT"
	usb_ssh_session_select "$ROOT"
	usb_ssh_session_configure_link
	usb_ssh_session_wait_for_target "$IFACE" "$TARGET_ADDR" "$WAIT_SEC"

	local cmd="${1:-}"
	case "$cmd" in
	trigger)
		shift
		trigger "${1:-}"
		;;
	clean)
		clean
		;;
	-h | --help | help | "")
		usage
		;;
	*)
		die "unknown subcommand: $cmd (expected: trigger, clean)"
		;;
	esac
}

main "$@"
