#!/bin/sh
# Sync wall clock after wlan0 has IPv4. HTTPS cert verify fails when RTC is
# stuck in the past (common without battery-backed RTC / NTP on first boot).
set -eu

log() {
	echo "wlan0-time-sync: $*" >&2
}

# Already sane (within a couple years of build/release era)? Skip churn.
year="$(date -u +%Y 2>/dev/null || echo 0)"
case "$year" in
2025|2026|2027|2028|2029|2030)
	log "clock year=$year — OK"
	exit 0
	;;
esac

log "clock looks stale ($(date -u -R 2>/dev/null || date -u)) — syncing"

# 1) RFC 868 (BusyBox rdate). Prefer well-known hosts; ignore LAN failures.
if command -v rdate >/dev/null 2>&1; then
	for host in time.nist.gov time.windows.com; do
		if rdate -s "$host" >/dev/null 2>&1; then
			log "rdate OK via $host → $(date -u -R 2>/dev/null || date -u)"
			hwclock -w -u 2>/dev/null || true
			exit 0
		fi
		log "rdate failed: $host"
	done
fi

# 2) HTTP Date header (BusyBox wget is HTTP-only; cleartext is enough).
if command -v wget >/dev/null 2>&1; then
	for url in http://www.baidu.com/ http://connectivitycheck.gstatic.com/generate_204; do
		hdr="$(wget -S -O /dev/null -T 8 "$url" 2>&1 | sed -n 's/^[[:space:]]*[Dd]ate:[[:space:]]*//p' | head -1 | tr -d '\r')"
		[ -n "$hdr" ] || continue
		# e.g. Tue, 14 Jul 2026 15:06:04 GMT
		if date -u -D "%a, %d %b %Y %H:%M:%S GMT" -s "$hdr" >/dev/null 2>&1; then
			log "HTTP Date OK via $url → $(date -u -R 2>/dev/null || date -u)"
			hwclock -w -u 2>/dev/null || true
			exit 0
		fi
		log "date -s failed for: $hdr"
	done
fi

log "WARN: could not sync clock; HTTPS may fail until RTC/NTP is fixed"
exit 0
