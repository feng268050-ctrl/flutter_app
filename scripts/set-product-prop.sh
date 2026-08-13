#!/usr/bin/env bash
# Upsert one or more keys into /var/lib/hal/properties.ini on the SSH target.
# Usage: make set-prop CAMERA_IP=192.168.1.50
# brand / model / sn are Vendor Storage identity — refused here (use write-identity).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"
# shellcheck source=scripts/product-ini-common.sh
source "$ROOT/scripts/product-ini-common.sh"

TARGET="${PROPERTIES_INI_PATH:-${PRODUCT_INI_PATH:-/var/lib/hal/properties.ini}}"

# Make / host workflow vars — not properties.ini keys.
# SN= remains device selection (exported by Make); never a set-prop product key.
_SET_PROP_SKIP=(
	SERIAL CHIP_ID IP IMAGE FLUTTER_SDK BUILD_JOBS BUILD_BIND_MOUNT
	USB_SSH_USER USB_SSH_ADDR IFACE
	DOCKER_IMAGE DOCKER_PLATFORM SCOPE FORCE SRC
	PRODUCT_INI_PATH PROPERTIES_INI_PATH
	SN
)

usage() {
	cat <<'EOF'
Usage:
  make set-prop <UPPERCASE_KEY>=<value> [<UPPERCASE_KEY>=<value> ...]

Examples:
  make set-prop CAMERA_IP=192.168.1.50 CAMERA_TYPE=2
  make set-prop CONTROL_CARD_COMM_ALARM_MODE=immediate

Command-line keys use UPPERCASE; values are written to /var/lib/hal/properties.ini
with lowercase keys. Multiple assignments are applied in one remote write.
brand / model / sn live in Vendor Storage (Rockchip) or provision/identity.env — use make write-identity (not set-prop).
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
# Refuses brand/model immediately. SN= is skipped (device selection) but noted.
collect_assignments() {
	local o key value
	local saw_sn_override=0
	PROP_KEYS=()
	PROP_VALUES=()
	for o in "$@"; do
		[[ "${o}" == *=* ]] || continue
		key="${o%%=*}"
		value="${o#*=}"
		[[ "${key}" =~ ^[A-Z][A-Z0-9_]*$ ]] || continue
		if is_oem_identity_product_key "${key}"; then
			if [[ "${key}" == "SN" ]]; then
				saw_sn_override=1
				continue
			fi
			refuse_oem_identity_product_key "${key}"
		fi
		is_skipped_make_var "${key}" && continue
		# GNU make escapes spaces in MAKEOVERRIDES.
		value="${value//\\ / }"
		PROP_KEYS+=("${key}")
		PROP_VALUES+=("${value}")
	done
	if [[ ${#PROP_KEYS[@]} -eq 0 ]]; then
		if [[ "${saw_sn_override}" -eq 1 ]]; then
			refuse_oem_identity_product_key "SN"
		fi
		return 1
	fi
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
	die "expected one or more UPPERCASE_KEY=value (example: make set-prop CAMERA_IP=192.168.1.50)"
}

require_ssh_identity "$ROOT"

usb_ssh_session_prepare "$ROOT"

if usb_ssh_session_is_remote; then
	echo "SSH set-prop: target=$TARGET_USER@$TARGET_ADDR -> $TARGET"
else
	echo "USB-SSH set-prop: iface=$IFACE target=$TARGET_USER@$TARGET_ADDR -> $TARGET"
fi

local_file="$(mktemp)"
trap 'rm -f "${local_file}"' EXIT

remote "mkdir -p '$(dirname "$TARGET")'"
# Prefer properties.ini; rename legacy product.ini on the device when needed.
remote "props='$TARGET'; dir=\$(dirname \"\$props\"); legacy=\"\$dir/product.ini\"; if [ ! -f \"\$props\" ] && [ -f \"\$legacy\" ]; then mv -f \"\$legacy\" \"\$props\"; fi" >/dev/null 2>&1 || true
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
