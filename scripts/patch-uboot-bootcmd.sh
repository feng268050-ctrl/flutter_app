#!/usr/bin/env bash
# DEPRECATED — binary patch breaks uboot env CRC on ynh960 (no backlight / maskrom).
# Do not use. Linux boot needs Innohi prebuilt uboot or serial boot_fit.
set -euo pipefail

die() {
  echo "ERROR: $*" >&2
  exit 1
}

die "binary uboot patch disabled on ynh960"
