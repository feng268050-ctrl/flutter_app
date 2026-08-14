#!/bin/sh
# Bind FHS subsystem state dirs to userdata (P2.3+). Call after userdata mount.
set -eu

. /usr/libexec/board/paths.sh

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

# Upsert key=value into conf; preserves sibling keys.
upsert_conf_key() {
	conf="$1"
	key="$2"
	value="$3"
	mkdir -p "$(dirname "$conf")"
	tmp="$(mktemp "${conf}.XXXXXX")"
	if [ -f "$conf" ]; then
		grep -vE "^${key}=" "$conf" >"$tmp" 2>/dev/null || true
	else
		: >"$tmp"
	fi
	printf '%s=%s\n' "$key" "$value" >>"$tmp"
	mv -f "$tmp" "$conf"
}

# Move known HAL files from HMI userdata into HAL; fold orientation into display.conf.
migrate_hal_from_hmi() {
	src_root="$1"
	dst_root="$2"
	[ -d "$src_root" ] || return 0
	mkdir -p "$dst_root"

	for name in display.conf sound.conf mouse.conf keyboard.conf input.conf datetime.conf \
		power.conf usb-otg.conf product.ini time-sync-mode timezone; do
		src="$src_root/$name"
		dst="$dst_root/$name"
		if [ -e "$src" ] && [ ! -e "$dst" ]; then
			log "migrate $src → $dst"
			cp -a "$src" "$dst"
			rm -f "$src"
		elif [ -e "$src" ] && [ -e "$dst" ]; then
			log "drop duplicate HAL source $src (dst exists)"
			rm -f "$src"
		fi
	done

	# Legacy product.ini on userdata — drop; properties.ini authority is provision.
	if [ -f "$dst_root/product.ini" ] || [ -f "$src_root/product.ini" ]; then
		log "drop legacy product.ini under userdata HAL (use provision properties.ini)"
		rm -f "$dst_root/product.ini" "$src_root/product.ini"
	fi
	if [ -f "$dst_root/properties.ini" ] || [ -f "$src_root/properties.ini" ]; then
		log "drop userdata HAL properties.ini (authoritative copy is on provision)"
		rm -f "$dst_root/properties.ini" "$src_root/properties.ini"
	fi

	# Fold legacy usb-debug into usb-otg.conf when conf missing.
	if [ ! -f "$dst_root/usb-otg.conf" ] && [ -f "$dst_root/usb-debug" ]; then
		case "$(tr -d '[:space:]' <"$dst_root/usb-debug" | tr '[:upper:]' '[:lower:]')" in
		0 | off | false | host)
			printf 'mode=host\n' >"$dst_root/usb-otg.conf"
			;;
		*)
			printf 'mode=debug\n' >"$dst_root/usb-otg.conf"
			;;
		esac
		log "fold usb-debug → usb-otg.conf ($(tr -d '[:space:]' <"$dst_root/usb-otg.conf"))"
		rm -f "$dst_root/usb-debug" "$src_root/usb-debug"
	fi
	rm -f "$src_root/usb-debug" 2>/dev/null || true

	# Fold legacy display-orientation into display.conf key orientation.
	orient_src=""
	if [ -f "$src_root/display-orientation" ]; then
		orient_src="$src_root/display-orientation"
	elif [ -f "$dst_root/display-orientation" ]; then
		orient_src="$dst_root/display-orientation"
	fi
	if [ -n "$orient_src" ]; then
		token="$(tr -d '[:space:]' <"$orient_src" | tr '[:upper:]' '[:lower:]')"
		case "$token" in
		portrait | landscape) ;;
		*) token=landscape ;;
		esac
		conf="$dst_root/display.conf"
		have_orient=0
		if [ -f "$conf" ] && grep -qE '^orientation=' "$conf" 2>/dev/null; then
			have_orient=1
		fi
		if [ "$have_orient" -eq 0 ]; then
			log "fold orientation=$token into $conf"
			upsert_conf_key "$conf" orientation "$token"
		fi
		rm -f "$src_root/display-orientation" "$dst_root/display-orientation"
	fi
}

if [ ! -d /userdata ]; then
	log "WARN: /userdata missing — keep state on rootfs"
	mkdir -p "$VAR_WPA" "$VAR_NETWORK" "$VAR_BLUETOOTH" "$VAR_HAL" "$VAR_HMI"
	exit 0
fi

bind_one "$VAR_WPA" "$USERDATA_WPA"
bind_one "$VAR_NETWORK" "$USERDATA_NETWORK"
bind_one "$VAR_BLUETOOTH" "$USERDATA_BLUETOOTH"
bind_one "$VAR_HAL" "$USERDATA_HAL"
bind_one "$VAR_HMI" "$USERDATA_HMI"

migrate_hal_from_hmi "$USERDATA_HMI" "$USERDATA_HAL"

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
	migrate_hal_from_hmi "$USERDATA_HMI" "$USERDATA_HAL"
fi

# Rename legacy product.ini already under HAL userdata (not only via HMI fold).
# properties.ini lives on provision — migrate handled by provision-mount.sh.
if [ -f "$USERDATA_HAL/product.ini" ]; then
	log "drop stale $USERDATA_HAL/product.ini (properties.ini is on provision)"
	rm -f "$USERDATA_HAL/product.ini"
fi
if [ -f "$USERDATA_HAL/properties.ini" ]; then
	log "drop stale $USERDATA_HAL/properties.ini (authoritative copy is on provision)"
	rm -f "$USERDATA_HAL/properties.ini"
fi

exit 0
