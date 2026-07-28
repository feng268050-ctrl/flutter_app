#!/usr/bin/env bash
# Shared P3.2 emulator process helpers (sourced by run-emulator / emulator-devices).
# Avoid `ps | grep qemu…` — the grep argv itself matches and creates phantom EMU rows.

# Requires: OUT (emulator output dir), optional ENDPOINT_FILE
# shellcheck disable=SC2034

lws_emulator_pids() {
	local pid cmd
	local img="${OUT:+$OUT/Image}"
	local rootfs="${OUT:+$OUT/rootfs.img}"

	# Prefer pgrep (does not match itself). Fall back to ps + bracket trick.
	if command -v pgrep >/dev/null 2>&1; then
		while read -r pid; do
			[[ "$pid" =~ ^[0-9]+$ ]] || continue
			cmd="$(ps -p "$pid" -o command= 2>/dev/null || true)"
			[[ -n "$cmd" ]] || continue
			_lws_emulator_cmd_is_ours "$cmd" "$img" "$rootfs" && printf '%s\n' "$pid"
		done < <(pgrep -f 'qemu-system-aarch64' 2>/dev/null || true)
		return 0
	fi

	# [q]emu… so this grep's own argv cannot match the pattern.
	ps -ax -o pid= -o command= 2>/dev/null | grep -E '[q]emu-system-aarch64' | while IFS= read -r line; do
		pid="$(printf '%s\n' "$line" | awk '{print $1}')"
		cmd="${line#"${pid}"}"
		cmd="${cmd#"${cmd%%[![:space:]]*}"}"
		_lws_emulator_cmd_is_ours "$cmd" "$img" "$rootfs" && printf '%s\n' "$pid"
	done
}

_lws_emulator_cmd_is_ours() {
	local cmd="$1" img="${2:-}" rootfs="${3:-}"
	case "$cmd" in
	*emulator-devices.sh* | *run-emulator.sh* | *expand-ext4-image*) return 1 ;;
	esac
	case "$cmd" in
	*qemu-system-aarch64*) ;;
	*) return 1 ;;
	esac
	case "$cmd" in
	*lws.emulator=1*) return 0 ;;
	esac
	[[ -n "$img" && "$cmd" == *"$img"* ]] && return 0
	[[ -n "$rootfs" && "$cmd" == *"$rootfs"* ]] && return 0
	# Path-agnostic markers when OUT differs (hardlink / copy).
	case "$cmd" in
	*/emulator/Image* | */emulator/rootfs.img*) return 0 ;;
	esac
	return 1
}

lws_emulator_running() {
	[[ -n "$(lws_emulator_pids | head -1)" ]]
}
