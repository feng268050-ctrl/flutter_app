#!/usr/bin/env bash
# Grow an ext4 image file (used for P3.2 emulator rootfs headroom).
# Device OTA artifact stays at BR2 600M; only the emulator working copy expands.
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }
log() { echo "expand-ext4-image: $*"; }

IMG="${1:-}"
SIZE="${2:-1536M}"
[[ -n "$IMG" && -f "$IMG" ]] || die "usage: $0 <ext4.img> [size]  (default size=1536M)"

# Parse human size → bytes (supports M/G suffix).
size_to_bytes() {
	local s="$1" n u
	n="$(printf '%s' "$s" | tr -d '[:space:]')"
	u="$(printf '%s' "$n" | sed -E 's/^[0-9]+//')"
	n="$(printf '%s' "$n" | sed -E 's/[^0-9].*$//')"
	[[ -n "$n" ]] || return 1
	case "$u" in
	"" | B | b) printf '%s\n' "$n" ;;
	K | k | KiB) printf '%s\n' "$((n * 1024))" ;;
	M | m | MiB) printf '%s\n' "$((n * 1024 * 1024))" ;;
	G | g | GiB) printf '%s\n' "$((n * 1024 * 1024 * 1024))" ;;
	*) return 1 ;;
	esac
}

want_bytes="$(size_to_bytes "$SIZE")" || die "invalid size: $SIZE"
cur_bytes="$(wc -c <"$IMG" | tr -d '[:space:]')"
if [[ "$cur_bytes" -ge "$want_bytes" ]]; then
	log "already ${cur_bytes} bytes (>= $SIZE) — skip grow: $IMG"
	exit 0
fi

log "growing $IMG → $SIZE (${cur_bytes} → ${want_bytes} bytes)"
truncate -s "$want_bytes" "$IMG"

run_resize() {
	# e2fsck: 0=clean, 1=errors corrected — both OK before resize2fs.
	e2fsck -fy "$IMG" || {
		local st=$?
		[[ "$st" -le 1 ]] || return "$st"
	}
	resize2fs "$IMG"
}

if command -v resize2fs >/dev/null 2>&1 && command -v e2fsck >/dev/null 2>&1; then
	run_resize
elif command -v docker >/dev/null 2>&1; then
	# macOS / hosts without e2fsprogs: alpine has resize2fs.
	abs="$(cd "$(dirname "$IMG")" && pwd)/$(basename "$IMG")"
	dir="$(dirname "$abs")"
	base="$(basename "$abs")"
	log "resize via Docker alpine e2fsprogs ($dir/$base)"
	docker run --rm -v "$dir:/work" alpine:3.20 \
		sh -c "apk add --no-cache e2fsprogs e2fsprogs-extra >/dev/null && \
			(e2fsck -fy /work/$base || st=\$?; [ \"\${st:-0}\" -le 1 ]) && \
			resize2fs /work/$base"
else
	die "need resize2fs+e2fsck, or Docker (alpine) to grow $IMG"
fi

log "done: $(wc -c <"$IMG" | tr -d '[:space:]') bytes"
