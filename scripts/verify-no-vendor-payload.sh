#!/usr/bin/env bash
# Fail if factory packaging would overwrite flash-surviving partitions.
# package-file must not list vendor0–vendor3 or provision; staging must not contain
# vendor*.img or provision.img.
#
# Usage: $0 [package-file] [firmware-staging-dir]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG="${1:-$ROOT/board/package-file-ynh960-linux-ab}"
FIRMWARE="${2:-}"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

[[ -f "$PKG" ]] || die "package-file missing: $PKG"

# Reject payload rows for vendor0–vendor3 and provision (comments / blank lines ignored).
if awk '
	BEGIN { bad = 0 }
	/^[[:space:]]*#/ { next }
	/^[[:space:]]*$/ { next }
	{
		name = $1
		sub(/\r$/, "", name)
		if (name ~ /^vendor[0-3]$/) {
			print "FAIL: package-file lists Vendor Storage partition: " name > "/dev/stderr"
			bad = 1
		}
		if (name == "provision") {
			print "FAIL: package-file lists provision partition: " name > "/dev/stderr"
			bad = 1
		}
	}
	END { exit bad }
' "$PKG"; then
	:
else
	die "package-file must not include vendor0–vendor3 or provision payloads (see docs/storage-layout.md)"
fi

# Also scan other known package-file variants in board/ (keep them clean).
for other in "$ROOT"/board/package-file-*; do
	[[ -f "$other" ]] || continue
	[[ "$other" == "$PKG" ]] && continue
	if awk '
		BEGIN { bad = 0 }
		/^[[:space:]]*#/ { next }
		/^[[:space:]]*$/ { next }
		{
			name = $1
			sub(/\r$/, "", name)
			if (name ~ /^vendor[0-3]$/) {
				print FILENAME ": lists " name > "/dev/stderr"
				bad = 1
			}
			if (name == "provision") {
				print FILENAME ": lists provision" > "/dev/stderr"
				bad = 1
			}
		}
		END { exit bad }
	' "$other"; then
		:
	else
		die "board package-file must not include vendor/provision payloads: $other"
	fi
done

if [[ -n "$FIRMWARE" ]]; then
	[[ -d "$FIRMWARE" ]] || die "firmware staging dir missing: $FIRMWARE"
	shopt -s nullglob
	vhits=("$FIRMWARE"/vendor*.img)
	shopt -u nullglob
	if [[ ${#vhits[@]} -gt 0 ]]; then
		echo "FAIL: vendor image(s) in factory staging:" >&2
		printf '  %s\n' "${vhits[@]}" >&2
		die "remove vendor*.img from staging — make flash must not overwrite Vendor Storage"
	fi
	# Literal path (no glob) — nullglob does not apply; must test -f explicitly.
	if [[ -f "$FIRMWARE/provision.img" ]]; then
		echo "FAIL: provision image in factory staging:" >&2
		printf '  %s\n' "$FIRMWARE/provision.img" >&2
		die "remove provision.img from staging — make flash must not overwrite provision"
	fi
fi

echo "OK: no vendor/provision payloads in package-file / staging"
