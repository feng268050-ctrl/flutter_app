#!/bin/bash
# ynh960: /userdata, /oem, private* are mounted by ynh960-display-init.sh (auto-mkfs).
# Rockchip 30-fstab.sh adds PARTLABEL=userdata → /userdata; must not stay in fstab.
set -euo pipefail

TARGET_DIR="${1:?TARGET_DIR required}"
FSTAB="$TARGET_DIR/etc/fstab"

[[ -f "$FSTAB" ]] || exit 0

for mp in /userdata /oem /mnt/private1 /mnt/private /mnt/userdata; do
	if grep -qE "[[:space:]]${mp//\//\\\/}[[:space:]]" "$FSTAB"; then
		sed -i "\|[[:space:]]${mp//\//\\\/}[[:space:]]|d" "$FSTAB"
		echo "post-strip-fstab: removed $mp from $FSTAB"
	fi
done

for label in userdata oem private private1; do
	if grep -qE "^PARTLABEL=${label}[[:space:]]" "$FSTAB"; then
		sed -i "/^PARTLABEL=${label}[[:space:]]/d" "$FSTAB"
		echo "post-strip-fstab: removed PARTLABEL=${label} from $FSTAB"
	fi
done
