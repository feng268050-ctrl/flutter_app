#!/bin/sh
# Stop on-demand LAN/WLAN SSH debug (wrapper around enable-ssh-debug.sh disable).
exec /usr/libexec/ssh/enable-ssh-debug.sh disable "$@"
