#!/usr/bin/env bash
# Remove one key from /var/lib/hal/properties.ini on the SSH target.
# Usage: make del-prop CAMERA_IP
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"
# shellcheck source=scripts/product-ini-common.sh
source "$ROOT/scripts/product-ini-common.sh"

TARGET="${PROPERTIES_INI_PATH:-${PRODUCT_INI_PATH:-/var/lib/hal/properties.ini}}"

_DEL_PROP_SKIP=(
	SERIAL CHIP_ID IP IMAGE FLUTTER_SDK BUILD_JOBS BUILD_BIND_MOUNT
	USB_SSH_USER USB_SSH_ADDR IFACE
	DOCKER_IMAGE DOCKER_PLATFORM SCOPE FORCE SRC
	PRODUCT_INI_PATH PROPERTIES_INI_PATH
)

usage() {
	cat <<'EOF'
Usage:
  make del-prop <UPPERCASE_KEY>

Examples:
  make del-prop CAMERA_IP
  make del-prop FOCUS_SCALE_REF

Command-line keys use UPPERCASE; the matching lowercase key is removed from
/var/lib/hal/properties.ini. brand / model / sn live in Vendor Storage or provision/identity.env (write-identity).
hmi.service is restarted only when the file changes.
EOF
}

die() { echo "ERROR: $*" >&2; exit 1; }

is_skipped_make_var() {
	local name="$1" skip
	for skip in "${_DEL_PROP_SKIP[@]}"; do
		[[ "${name}" == "${skip}" ]] && return 0
	done
	return 1
}

find_prop_key() {
	local o key
	PROP_KEY=""
	for o in "$@"; do
		if [[ "${o}" == *=* ]]; then
			key="${o%%=*}"
		elif [[ "${o}" =~ ^[A-Z][A-Z0-9_]*$ ]]; then
			key="${o}"
		else
			continue
		fi
		is_skipped_make_var "${key}" && continue
		[[ "${key}" =~ ^[A-Z][A-Z0-9_]*$ ]] || continue
		if [[ -n "${PROP_KEY}" ]]; then
			die "delete one property at a time (got ${PROP_KEY} and ${key})"
		fi
		PROP_KEY="${key}"
	done
	[[ -n "${PROP_KEY}" ]] || return 1
}

remote() {
	usb_ssh_session_run_ssh "$ROOT" "$IFACE" "$@"
}

find_prop_key "$@" || {
	usage
	die "expected one UPPERCASE_KEY (example: make del-prop CAMERA_IP)"
}
refuse_oem_identity_product_key "${PROP_KEY}"
KEY="$(printf '%s' "${PROP_KEY}" | tr '[:upper:]' '[:lower:]')"

require_ssh_identity "$ROOT"

usb_ssh_session_prepare "$ROOT"

if usb_ssh_session_is_remote; then
	echo "SSH del-prop: target=$TARGET_USER@$TARGET_ADDR -> $TARGET"
else
	echo "USB-SSH del-prop: iface=$IFACE target=$TARGET_USER@$TARGET_ADDR -> $TARGET"
fi

remote "props='$TARGET'; dir=\$(dirname \"\$props\"); legacy=\"\$dir/product.ini\"; if [ ! -f \"\$props\" ] && [ -f \"\$legacy\" ]; then mv -f \"\$legacy\" \"\$props\"; fi" >/dev/null 2>&1 || true

if ! remote "test -f '$TARGET'" >/dev/null 2>&1; then
	echo "WARN: ${KEY} not present (${TARGET} missing) (from ${PROP_KEY})" >&2
	exit 0
fi

local_file="$(mktemp)"
trap 'rm -f "${local_file}"' EXIT

usb_ssh_session_run_scp "$ROOT" "$IFACE" \
	"${TARGET_USER}@${TARGET_ADDR}:${TARGET}" "${local_file}" \
	|| die "failed to pull ${TARGET}"

if delete_product_ini_from_file "${KEY}" "${local_file}"; then
	echo "INFO: removing ${KEY} from ${TARGET} (from ${PROP_KEY})..." >&2
	usb_ssh_session_run_scp "$ROOT" "$IFACE" \
		"${local_file}" "${TARGET_USER}@${TARGET_ADDR}:${TARGET}" \
		|| die "failed to push ${TARGET}"
	remote "chmod 0644 '$TARGET'" >/dev/null 2>&1 || true
	echo "OK: removed ${KEY} from ${TARGET}"
	echo "INFO: restarting hmi.service..." >&2
	remote "systemctl restart hmi.service" || die "failed to restart hmi.service"
else
	echo "WARN: ${KEY} not present in ${TARGET} (from ${PROP_KEY})" >&2
fi
