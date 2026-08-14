#!/bin/sh
# Switch Flutter seat to OS Settings (stops hmi.service via Conflicts=).
set -eu
exec systemctl start os-settings.service
