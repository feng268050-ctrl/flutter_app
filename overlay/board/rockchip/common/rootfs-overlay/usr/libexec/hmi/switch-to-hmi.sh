#!/bin/sh
# Switch Flutter seat back to product HMI (stops os-settings.service via Conflicts=).
set -eu
exec systemctl start hmi.service
