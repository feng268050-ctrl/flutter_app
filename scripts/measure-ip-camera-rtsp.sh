#!/usr/bin/env bash
# Measure inbound RTSP receive bitrate from an IP camera plugged into this Mac.
#
# Setup (macOS — assign a static IP on 192.168.1.0/24 so the camera is reachable):
#   1. System Settings → Network → Ethernet (or USB/Thunderbolt adapter linked to the camera)
#   2. Configure IPv4 → Manually:
#        IP address: 192.168.1.234
#        Subnet mask: 255.255.255.0
#        Router: (leave blank, or 192.168.1.1 if you use a gateway)
#   Or CLI (replace enX with the Device from `networksetup -listallhardwareports`):
#        sudo ifconfig enX inet 192.168.1.234 netmask 255.255.255.0 up
#   3. Plug camera RJ45 → Mac (direct cable or a simple switch on that subnet)
#   4. Run this script
#
# Compare Mac Mbps vs board remux (see docs/ip-camera-rtsp-bitrate-android-vs-linux.md).
# Healthy Linux/Android boards match Mac (~3.4 Mbps PR1 UDP); low remux + high
# ethtool mmc_rx_crc_error usually means RMII clock_in_out / DTS mismatch.
#
# Usage:
#   scripts/measure-ip-camera-rtsp.sh
#   scripts/measure-ip-camera-rtsp.sh 15
#   DURATION_S=15 STREAM=PR0 scripts/measure-ip-camera-rtsp.sh
#   RTSP_URL=rtsp://192.168.1.100/PR1 scripts/measure-ip-camera-rtsp.sh
#
# Env:
#   CAMERA_IP         default 192.168.1.100
#   STREAM            default PR1 (preview); optionally PR0
#   RTSP_URL          override full URL (ignores CAMERA_IP/STREAM)
#   DURATION_S        seconds to pull (default 10; argv[1] overrides)
#   RTSP_TRANSPORT    udp|tcp (default udp — match board path)
set -euo pipefail

CAMERA_IP="${CAMERA_IP:-192.168.1.100}"
STREAM="${STREAM:-PR1}"
DURATION_S="${1:-${DURATION_S:-10}}"
RTSP_TRANSPORT="${RTSP_TRANSPORT:-udp}"
RTSP_URL="${RTSP_URL:-rtsp://${CAMERA_IP}/${STREAM}}"

if ! [[ "$DURATION_S" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: DURATION_S must be a positive integer (got: $DURATION_S)" >&2
  exit 2
fi

have() { command -v "$1" >/dev/null 2>&1; }

bytes_of() {
  local path="$1"
  stat -f '%z' "$path" 2>/dev/null || stat -c '%s' "$path"
}

mbps_of() {
  local bytes="$1" secs="$2"
  awk -v b="$bytes" -v s="$secs" 'BEGIN {
    if (s <= 0) { print "0.00"; exit }
    printf "%.2f", (b * 8) / s / 1000000
  }'
}

ping_camera() {
  echo "==> ping ${CAMERA_IP}"
  # Darwin: -W is ms; Linux: -W is seconds. Prefer short portable -c/-t style.
  if [[ "$(uname -s)" == Darwin ]]; then
    ping -c 3 -W 2000 "$CAMERA_IP"
  else
    ping -c 3 -W 2 "$CAMERA_IP"
  fi
}

print_summary() {
  local backend="$1" bytes="$2" elapsed="$3" log="${4:-}"
  local mbps packets missed
  mbps="$(mbps_of "$bytes" "$elapsed")"
  echo ""
  echo "==> result (${backend})"
  echo "    URL:          ${RTSP_URL}"
  echo "    transport:    ${RTSP_TRANSPORT}"
  echo "    duration:     ${elapsed}s"
  echo "    bytes:        ${bytes}"
  echo "    bitrate:      ${mbps} Mbps"
  if [[ -n "$log" && -f "$log" ]]; then
    # ffmpeg RTP notes (when present)
    missed="$(grep -Eo 'RTP: (missed|lost) [0-9]+' "$log" 2>/dev/null | tail -1 || true)"
    packets="$(grep -Eo 'packet[^:]*: *[0-9]+' "$log" 2>/dev/null | tail -1 || true)"
    [[ -n "$missed" ]] && echo "    rtp:          ${missed}"
    [[ -n "$packets" ]] && echo "    note:         ${packets}"
  fi
  echo ""
  echo "Compare to board ~2.5 Mbps UDP: if Mac is much higher, suspect board eth0/PHY/path."
}

measure_ffmpeg() {
  local out log start end elapsed bytes
  out="$(mktemp "${TMPDIR:-/tmp}/measure-ipcam.XXXXXX.ts")"
  log="$(mktemp "${TMPDIR:-/tmp}/measure-ipcam.XXXXXX.log")"
  # shellcheck disable=SC2064
  trap "rm -f '$out' '$log'" RETURN

  echo "==> ffmpeg pull ${DURATION_S}s (${RTSP_TRANSPORT}) → measure remux size"
  start="$(date +%s)"
  # Remux only: received payload ≈ file size (mpegts overhead is small).
  if ! ffmpeg -hide_banner -nostdin \
    -rtsp_transport "$RTSP_TRANSPORT" \
    -i "$RTSP_URL" \
    -t "$DURATION_S" \
    -c copy \
    -f mpegts \
    -y "$out" \
    >"$log" 2>&1; then
    echo "ERROR: ffmpeg failed. Last log lines:" >&2
    tail -n 40 "$log" >&2 || true
    return 1
  fi
  end="$(date +%s)"
  elapsed=$((end - start))
  [[ "$elapsed" -lt 1 ]] && elapsed=1
  bytes="$(bytes_of "$out")"
  if [[ "${bytes:-0}" -le 0 ]]; then
    echo "ERROR: ffmpeg wrote 0 bytes (no media received?)." >&2
    tail -n 40 "$log" >&2 || true
    return 1
  fi
  print_summary "ffmpeg" "$bytes" "$elapsed" "$log"
}

measure_gst() {
  local out log start end elapsed bytes pid
  out="$(mktemp "${TMPDIR:-/tmp}/measure-ipcam.XXXXXX.bin")"
  log="$(mktemp "${TMPDIR:-/tmp}/measure-ipcam.XXXXXX.log")"
  # shellcheck disable=SC2064
  trap "rm -f '$out' '$log'" RETURN

  local proto="udp"
  [[ "$RTSP_TRANSPORT" == tcp ]] && proto="tcp"

  echo "==> gst-launch-1.0 pull ${DURATION_S}s (${proto}) → measure file size"
  start="$(date +%s)"
  # Depay to elementary stream; size ≈ received media bytes.
  gst-launch-1.0 -e \
    "rtspsrc location=${RTSP_URL} protocols=${proto} latency=200" \
    ! rtph264depay \
    ! filesink location="$out" \
    >"$log" 2>&1 &
  pid=$!
  sleep "$DURATION_S"
  # Ask pipeline to EOS; fall back to kill if it ignores.
  kill -INT "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  end="$(date +%s)"
  elapsed=$((end - start))
  [[ "$elapsed" -lt 1 ]] && elapsed="$DURATION_S"
  bytes="$(bytes_of "$out")"
  if [[ "${bytes:-0}" -le 0 ]]; then
    echo "ERROR: gstreamer wrote 0 bytes (no media received?)." >&2
    tail -n 40 "$log" >&2 || true
    return 1
  fi
  print_summary "gst-launch-1.0" "$bytes" "$elapsed" "$log"
}

echo "measure-ip-camera-rtsp: camera=${CAMERA_IP} stream=${STREAM} duration=${DURATION_S}s"
echo "URL: ${RTSP_URL}"
echo ""

if ! ping_camera; then
  echo "" >&2
  echo "ERROR: camera ${CAMERA_IP} not reachable. Set Mac NIC to 192.168.1.234/24 and re-check cabling." >&2
  exit 1
fi
echo ""

if have ffmpeg; then
  measure_ffmpeg
elif have gst-launch-1.0; then
  echo "NOTE: ffmpeg not found; falling back to gst-launch-1.0"
  measure_gst
else
  echo "ERROR: need ffmpeg (preferred) or gst-launch-1.0 on PATH." >&2
  echo "  macOS: brew install ffmpeg" >&2
  echo "     or: brew install gstreamer gst-plugins-base gst-plugins-good gst-plugins-ugly" >&2
  exit 1
fi
