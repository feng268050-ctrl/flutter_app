#!/bin/sh
# Start tee-supplicant for HAL Secrets.
# - Interim: REE FS parent on /userdata/tee (A/B-safe; wiped by factory flash).
# - Target: RPMB KEK via -r <eMMC CID> once vendor BL32 enables CFG_RPMB_FS.
set -eu

DEV="${TEE_DEVICE:-/dev/teepriv0}"
FS_PARENT="${TEE_FS_PARENT:-/userdata/tee}"
CID_FILE="${RPMB_CID_FILE:-/sys/block/mmcblk0/device/cid}"

mkdir -p "$FS_PARENT"

ARGS="-f $FS_PARENT"
if [ -r "$CID_FILE" ]; then
	CID=$(tr -d ' \n' <"$CID_FILE")
	if [ -n "$CID" ]; then
		ARGS="$ARGS -r $CID"
	fi
fi

# shellcheck disable=SC2086
exec /usr/sbin/tee-supplicant $ARGS "$DEV"
