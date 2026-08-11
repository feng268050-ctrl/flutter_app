#!/bin/sh
# Restart whichever Flutter seat owns the display (os-settings or hmi).
# Used when Weston ini / compositor prefs need a client restart.
set -eu

pick_seat_unit() {
	if command -v systemctl >/dev/null 2>&1; then
		if systemctl is-active --quiet os-settings.service 2>/dev/null; then
			printf '%s\n' os-settings.service
			return 0
		fi
		if systemctl is-active --quiet hmi.service 2>/dev/null; then
			printf '%s\n' hmi.service
			return 0
		fi
	fi
	# Fallback when systemd state is unclear but Weston is up.
	printf '%s\n' hmi.service
}

unit="$(pick_seat_unit)"
echo "restart-flutter-seat: restarting $unit" >&2
if command -v systemctl >/dev/null 2>&1; then
	systemctl reset-failed "$unit" 2>/dev/null || true
	nohup systemctl restart "$unit" >/dev/null 2>&1 &
fi

exit 0
