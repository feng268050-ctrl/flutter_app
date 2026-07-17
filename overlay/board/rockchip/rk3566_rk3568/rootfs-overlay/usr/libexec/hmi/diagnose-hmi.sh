#!/bin/sh
# HMI boot diagnostics when splash logo never hands off to Flutter.
set -u

echo "=== diagnose-hmi ==="

echo ""
echo "--- hmi.service ---"
systemctl status hmi.service --no-pager 2>/dev/null || true

echo ""
echo "--- journal (last 40 lines) ---"
journalctl -u hmi.service -n 40 --no-pager 2>/dev/null || true

echo ""
echo "--- flutter-pi process ---"
if pidof flutter-pi >/dev/null 2>&1; then
	ps aux | grep '[f]lutter-pi' || true
else
	echo "flutter-pi not running"
fi

echo ""
echo "--- bundle + engine ---"
ls -la /opt/hmi/lib/libapp.so 2>/dev/null || echo "missing /opt/hmi/lib/libapp.so"
ls -la /opt/hmi/lib/libflutter_engine.so 2>/dev/null && \
	echo "WARN: bundle engine present (should use /usr/lib only)" || true
ls -la /usr/lib/libflutter_engine.so 2>/dev/null || echo "missing /usr/lib/libflutter_engine.so"
ls -la /usr/share/flutter/icudtl.dat /usr/share/flutter/release/data/icudtl.dat 2>/dev/null || true

echo ""
echo "--- manual smoke (foreground, Ctrl+C to stop) ---"
echo "  systemctl stop hmi.service"
	echo "  /usr/bin/flutter-pi --release -o landscape_left /opt/hmi"
	echo "  (or portrait_up if /var/lib/lws-hmi/display-orientation is portrait)"
