#!/usr/bin/env bash
# Upsert one or more keys into /var/lib/hal/product.ini on the SSH target.
# Usage: make set-prop BRAND=Innohi MODEL=YNH960 CAMERA_IP=192.168.1.50
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"
# shellcheck source=scripts/product-ini-common.sh
source "$ROOT/scripts/product-ini-common.sh"

TARGET="${PRODUCT_INI_PATH:-/var/lib/hal/product.ini}"

# Make / host workflow vars — not product.ini keys.
# Note: SN is a product key (make set-prop SN=…); do not skip it.
# Device selection for set-prop uses CHIPID= / IP= / SERIAL= (deprecated) when SN= is a prop.
_SET_PROP_SKIP=(
	SERIAL CHIPID IP IMAGE FLUTTER_SDK BUILD_JOBS BUILD_BIND_MOUNT
	LWS_HMI_SERIAL LWS_HMI_SN LWS_HMI_CHIPID LWS_HMI_IP LWS_HMI_USB_SSH_PASS LWS_HMI_USB_SSH_USER
	LWS_HMI_USB_SSH_ADDR LWS_HMI_USB_IFACE PUSH_APP_WAIT_SEC
	DOCKER_IMAGE DOCKER_PLATFORM SCOPE FORCE SRC
	PRODUCT_INI_PATH
)

usage() {
	cat <<'EOF'
Usage:
  make set-prop <UPPERCASE_KEY>=<value> [<UPPERCASE_KEY>=<value> ...]

Examples:
  make set-prop BRAND=Innohi MODEL=YNH960 SN=FACTORY-001
  make set-prop CAMERA_IP=192.168.1.50 CAMERA_TYPE=2
  make set-prop CONTROL_CARD_COMM_ALARM_MODE=immediate

Command-line keys use UPPERCASE; values are written to /var/lib/hal/product.ini
with lowercase keys. Multiple assignments are applied in one remote write.
hmi.service is restarted once after a successful write.
EOF
}

die() { echo "ERROR: $*" >&2; exit 1; }

is_skipped_make_var() {
	local name="$1" skip
	for skip in "${_SET_PROP_SKIP[@]}"; do
		[[ "${name}" == "${skip}" ]] && return 0
	done
	return 1
}

# Fills PROP_KEYS[] and PROP_VALUES[] (parallel arrays).
collect_assignments() {
	local o key value
	PROP_KEYS=()
	PROP_VALUES=()
	for o in "$@"; do
		[[ "${o}" == *=* ]] || continue
		key="${o%%=*}"
		value="${o#*=}"
		is_skipped_make_var "${key}" && continue
		[[ "${key}" =~ ^[A-Z][A-Z0-9_]*$ ]] || continue
		# GNU make escapes spaces in MAKEOVERRIDES (e.g. MODEL=LaserCyber\ L1\ Pro).
		value="${value//\\ / }"
		PROP_KEYS+=("${key}")
		PROP_VALUES+=("${value}")
	done
	[[ ${#PROP_KEYS[@]} -gt 0 ]] || return 1
}

remote() {
	usb_ssh_session_run_ssh "$ROOT" "$IFACE" "$@"
}

restart_hmi() {
	echo "INFO: restarting hmi.service..." >&2
	remote "systemctl restart hmi.service" || die "failed to restart hmi.service"
}

collect_assignments "$@" || {
	usage
	die "expected one or more UPPERCASE_KEY=value (example: make set-prop BRAND=Innohi MODEL=YNH960)"
}

# SN= as a product key must not also act as device selection (use CHIPID= / IP= / SERIAL=).
for _k in "${PROP_KEYS[@]}"; do
	if [[ "${_k}" == "SN" ]]; then
		unset SN LWS_HMI_SN
		break
	fi
done

command -v sshpass >/dev/null 2>&1 || die "sshpass not found (run: make usb-ssh-setup)"

usb_ssh_session_prepare "$ROOT"

if usb_ssh_session_is_remote; then
	echo "SSH set-prop: target=$TARGET_USER@$TARGET_ADDR -> $TARGET"
else
	echo "USB-SSH set-prop: iface=$IFACE target=$TARGET_USER@$TARGET_ADDR -> $TARGET"
fi

local_file="$(mktemp)"
trap 'rm -f "${local_file}"' EXIT

remote "mkdir -p '$(dirname "$TARGET")'"
if remote "test -f '$TARGET'" >/dev/null 2>&1; then
	usb_ssh_session_run_scp "$ROOT" "$IFACE" \
		"${TARGET_USER}@${TARGET_ADDR}:${TARGET}" "${local_file}" \
		|| die "failed to pull ${TARGET}"
else
	: >"${local_file}"
fi

i=0
for ((i = 0; i < ${#PROP_KEYS[@]}; i++)); do
	ukey="${PROP_KEYS[$i]}"
	value="${PROP_VALUES[$i]}"
	lkey="$(printf '%s' "${ukey}" | tr '[:upper:]' '[:lower:]')"
	upsert_product_ini_in_file "${lkey}" "${value}" "${local_file}"
	echo "INFO: upsert ${lkey}=${value} (from ${ukey})" >&2
done

usb_ssh_session_run_scp "$ROOT" "$IFACE" \
	"${local_file}" "${TARGET_USER}@${TARGET_ADDR}:${TARGET}" \
	|| die "failed to push ${TARGET}"
remote "chmod 0644 '$TARGET'" >/dev/null 2>&1 || true

echo "OK: wrote ${#PROP_KEYS[@]} propert$([[ ${#PROP_KEYS[@]} -eq 1 ]] && echo y || echo ies) -> ${TARGET}"
restart_hmi
