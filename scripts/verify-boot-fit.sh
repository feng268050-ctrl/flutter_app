#!/usr/bin/env bash
# Verify multi-configuration boot FIT against board/rk356x-fit-boards.txt and GPT size.
# Usage: scripts/verify-boot-fit.sh <firmware-dir> [boot.img-name]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIRMWARE="${1:-}"
BOOT_NAME="${2:-boot.img}"
INVENTORY="${FIT_BOARD_INVENTORY:-$ROOT/board/rk356x-fit-boards.txt}"
PARAM="${FIT_PARAM:-$ROOT/board/parameter-buildroot-fit.txt}"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

[[ -d "$FIRMWARE" ]] || die "usage: $0 <firmware-dir> [boot.img|boot_b.img]"
[[ -r "$INVENTORY" ]] || die "missing inventory: $INVENTORY"

BOOT_IMG="$FIRMWARE/$BOOT_NAME"
[[ -r "$BOOT_IMG" ]] || die "missing $BOOT_IMG"

boards=()
while IFS= read -r line || [[ -n "$line" ]]; do
	line="${line%%#*}"
	line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
	[[ -z "$line" ]] && continue
	boards+=("$line")
done <"$INVENTORY"
[[ ${#boards[@]} -ge 1 ]] || die "empty board inventory"

echo "verify-boot-fit: $BOOT_IMG"
echo "inventory boards: ${boards[*]}"

# Prefer mkimage -l when available; else scan printable FIT strings for conf nodes.
list_confs() {
	local img="$1"
	local mk=""
	local c
	for c in \
		"${SDK_DIR:-$ROOT/linux-sdk}/rkbin/tools/mkimage" \
		"$ROOT/linux-sdk/rkbin/tools/mkimage"; do
		if [[ -x "$c" ]]; then
			mk="$c"
			break
		fi
	done
	if [[ -n "$mk" ]]; then
		"$mk" -l "$img" 2>/dev/null | awk '
			/Default Configuration:/ {
				gsub(/['\''"]/, "", $NF); print $NF; next
			}
			/^ Configuration [0-9]+ \(/ {
				line=$0
				sub(/^.*\(/, "", line)
				sub(/\).*$/, "", line)
				print line
			}
		' | sort -u
		return 0
	fi
	# Fallback: FIT stores configuration unit names as path components under /configurations/
	python3 - "$img" <<'PY'
import re, sys
from pathlib import Path
data = Path(sys.argv[1]).read_bytes()
# Look for "configurations" then following printable node names near FIT structure.
text = data.decode("latin1", errors="ignore")
# Common: unit names appear as C-strings; require inventory-like tokens via caller check.
# Emit candidates that look like board ids (alphanumeric + _ -).
cands = set(re.findall(r"\x00([a-z][a-z0-9_-]{2,31})\x00", data.decode("latin1", errors="ignore") if False else ""))
# Binary-safe scan for NUL-terminated strings
out = []
i = 0
n = len(data)
while i < n:
    if 0x20 <= data[i] < 0x7f:
        j = i
        while j < n and 0x20 <= data[j] < 0x7f:
            j += 1
        if j < n and data[j] == 0 and 3 <= (j - i) <= 32:
            s = data[i:j].decode("ascii")
            if re.fullmatch(r"[a-z][a-z0-9_-]*", s):
                out.append(s)
        i = j + 1
    else:
        i += 1
# De-dupe preserving order
seen = set()
for s in out:
    if s not in seen:
        seen.add(s)
        print(s)
PY
}

confs_raw="$(list_confs "$BOOT_IMG" || true)"
echo "FIT printable/conf candidates:"
echo "$confs_raw" | sed 's/^/  /' | head -40

missing=0
for b in "${boards[@]}"; do
	if echo "$confs_raw" | grep -qx "$b"; then
		echo "OK conf: $b"
	elif grep -aFq "$b" "$BOOT_IMG" && grep -aFq "fdt-${b}" "$BOOT_IMG"; then
		# Strong signal from ITS unit names embedded in FIT
		echo "OK conf (embedded fdt-${b}): $b"
	elif grep -aFq "$b" "$BOOT_IMG"; then
		echo "OK conf (string present): $b"
	else
		echo "FAIL: inventory board '$b' not found in FIT" >&2
		missing=1
	fi
done

# Size gate (same helper as factory/upgrade)
bash "$ROOT/scripts/verify-firmware-partitions.sh" "$FIRMWARE" "$PARAM" \
	|| die "partition size check failed"

# resource.img inside FIT: RSCE ENTR SHA-1 + PARTLABEL (ynh960 U-Boot root=)
# boot.img → rootfs_a; boot_b.img → rootfs_b. Stale hash after PARTLABEL patch
# caused B-only missing splash / UI jank / cold-boot panic — see docs/ab-slot-misc.md.
expect_pl=""
case "$BOOT_NAME" in
boot.img) expect_pl=rootfs_a ;;
boot_b.img) expect_pl=rootfs_b ;;
esac
if [[ -n "$expect_pl" ]]; then
	python3 "$ROOT/scripts/patch-resource-img-partlabel.py" --verify "$BOOT_IMG" "$expect_pl" \
		|| die "resource RSCE verify failed for $BOOT_NAME (docs/ab-slot-misc.md)"
fi

[[ "$missing" -eq 0 ]] || die "FIT missing one or more inventory configurations"
echo "verify-boot-fit: OK"
