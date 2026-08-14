#!/bin/sh
# Virt guest: do not run Rockchip / ynh960 ParamUpdate display-init.
# Real display-init stays on device OEM; this stub satisfies unit Wants if present.
set -eu
echo "display-init: skipped on virt guest"
exit 0
