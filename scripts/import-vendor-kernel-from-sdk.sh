#!/usr/bin/env bash
# One-off: refresh overlay vendor kernel from local linux-sdk/.
# Normal workflow edits overlay/ directly; run apply-overlay before build-kernel.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${SDK_DIR:-$ROOT/linux-sdk}"

die() { echo "ERROR: $*" >&2; exit 1; }

[[ -d "$SDK/kernel" ]] || die "missing $SDK/kernel"

echo "import: aic8800 driver"
mkdir -p "$ROOT/overlay/kernel/drivers/net/wireless"
rsync -a --delete \
  --exclude='*.o' --exclude='*.ko' --exclude='*.mod' --exclude='*.mod.c' \
  "$SDK/kernel/drivers/net/wireless/aic8800/" \
  "$ROOT/overlay/kernel/drivers/net/wireless/aic8800/"

echo "import: skip kernel/innohi (retired — gpio_innohi → gpiod; do not re-create overlay/kernel/innohi)"
rm -rf "$ROOT/overlay/kernel/innohi"

UDEV_SRC="$SDK/innohi/rootfs/usr/lib/udev/rules.d/61-partition-init.rules"
UDEV_DST="$ROOT/overlay/board/rockchip/common/rootfs-overlay/usr/lib/udev/rules.d/61-partition-init.rules"
if [[ -f "$UDEV_SRC" ]]; then
  echo "import: 61-partition-init.rules → platform rootfs overlay"
  mkdir -p "$(dirname "$UDEV_DST")"
  install -m 0644 "$UDEV_SRC" "$UDEV_DST"
else
  echo "import: skip udev rules (no $UDEV_SRC)"
fi

du -sh "$ROOT/overlay/kernel/drivers/net/wireless/aic8800"
echo "import: done — run make apply-overlay && FORCE_KERNEL_IMAGE=1 make build-kernel"
