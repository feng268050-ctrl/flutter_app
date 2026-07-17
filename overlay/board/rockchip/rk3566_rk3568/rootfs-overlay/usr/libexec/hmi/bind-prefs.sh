#!/bin/sh
# Bind FHS subsystem state dirs to userdata (P2.3+). Call after userdata mount.
set -eu

. /usr/libexec/hmi/paths.sh

log() {
	echo "bind-prefs: $*"
}

bind_one() {
	var_path=$1
	userdata_path=$2
	mkdir -p "$userdata_path"
	if [ -d "$var_path" ] && [ ! -L "$var_path" ]; then
		log "fold $var_path → $userdata_path"
		cp -an "$var_path"/. "$userdata_path"/ 2>/dev/null || true
		rm -rf "$var_path"
	fi
	if [ -L "$var_path" ]; then
		target="$(readlink "$var_path" 2>/dev/null || true)"
		if [ "$target" = "$userdata_path" ]; then
			return 0
		fi
		rm -f "$var_path"
	fi
	if [ -d "$var_path" ]; then
		cp -an "$var_path"/. "$userdata_path"/ 2>/dev/null || true
		rm -rf "$var_path"
	fi
	ln -sfn "$userdata_path" "$var_path"
	log "ok ($var_path → $userdata_path)"
}

if [ ! -d /userdata ]; then
	log "WARN: /userdata missing — keep state on rootfs"
	mkdir -p "$VAR_WPA" "$VAR_NETWORK" "$VAR_BLUETOOTH" "$VAR_HMI"
	exit 0
fi

bind_one "$VAR_WPA" "$USERDATA_WPA"
bind_one "$VAR_NETWORK" "$USERDATA_NETWORK"
bind_one "$VAR_BLUETOOTH" "$USERDATA_BLUETOOTH"
bind_one "$VAR_HMI" "$USERDATA_HMI"

# One-time fold of pre-rename monolithic userdata (fix-hmi-system-naming).
legacy_userdata=/userdata/lws-hmi
if [ -d "$legacy_userdata" ] && [ ! -L "$legacy_userdata" ]; then
	if [ -d "$USERDATA_HMI" ] && [ -n "$(ls -A "$USERDATA_HMI" 2>/dev/null)" ]; then
		log "fold legacy $legacy_userdata snippets → $USERDATA_HMI"
		cp -an "$legacy_userdata"/. "$USERDATA_HMI"/ 2>/dev/null || true
	else
		log "rename $legacy_userdata → $USERDATA_HMI"
		mv "$legacy_userdata" "$USERDATA_HMI"
	fi
	if [ -d "$legacy_userdata" ]; then
		rm -rf "$legacy_userdata"
	fi
fi

exit 0
