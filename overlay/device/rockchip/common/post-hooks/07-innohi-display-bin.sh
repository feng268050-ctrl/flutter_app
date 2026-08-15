#!/bin/bash -e

# Innohi userspace leftovers (display binaries retired).
# Kernel combo Wi‑Fi: overlay/kernel/drivers/net/wireless/aic8800/ (gpio_innohi tree removed).

source "${RK_POST_HELPER:-$(dirname "$(realpath "$0")")/post-helper}"

[ "$POST_OS" = buildroot ] || exit 0

echo "post-innohi: skip MountAll/ParamUpdate/MainServer (DTS-only display)"
