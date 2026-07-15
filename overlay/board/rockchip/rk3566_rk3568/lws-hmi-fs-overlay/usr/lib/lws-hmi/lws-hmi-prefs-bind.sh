#!/bin/sh
# Point /var/lib/lws-hmi at /userdata/lws-hmi so prefs survive rootfs flash.
# Call after userdata is mounted (ynh960-display-init / param-update).
set -eu

USERDATA_PREFS=/userdata/lws-hmi
VAR_PREFS=/var/lib/lws-hmi

log() {
	echo "lws-hmi-prefs-bind: $*"
}

if [ ! -d /userdata ]; then
	log "WARN: /userdata missing — keep $VAR_PREFS on rootfs"
	mkdir -p "$VAR_PREFS"
	exit 0
fi

mkdir -p "$USERDATA_PREFS"

# Migrate one-shot from seed/runtime rootfs dir without clobbering userdata.
if [ -d "$VAR_PREFS" ] && [ ! -L "$VAR_PREFS" ]; then
	log "migrating $VAR_PREFS → $USERDATA_PREFS"
	cp -an "$VAR_PREFS"/. "$USERDATA_PREFS"/ 2>/dev/null || true
	rm -rf "$VAR_PREFS"
fi

if [ -L "$VAR_PREFS" ]; then
	target="$(readlink "$VAR_PREFS" 2>/dev/null || true)"
	if [ "$target" = "$USERDATA_PREFS" ]; then
		log "ok ($VAR_PREFS → $USERDATA_PREFS)"
		exit 0
	fi
	rm -f "$VAR_PREFS"
fi

# If a directory still exists (race), fold then replace.
if [ -d "$VAR_PREFS" ]; then
	cp -an "$VAR_PREFS"/. "$USERDATA_PREFS"/ 2>/dev/null || true
	rm -rf "$VAR_PREFS"
fi

ln -sfn "$USERDATA_PREFS" "$VAR_PREFS"
log "ok ($VAR_PREFS → $USERDATA_PREFS)"
