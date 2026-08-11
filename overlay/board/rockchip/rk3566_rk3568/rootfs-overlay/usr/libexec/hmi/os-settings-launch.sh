#!/bin/sh
# OS Settings launcher: same Weston + flutter-wayland-client path as HMI.
# Bundle is /opt/os_settings (non-HMI; no MediaMTX/AI companions).
set -eu
export BUNDLE=/opt/os_settings
exec /usr/libexec/hmi/hmi-launch.sh
