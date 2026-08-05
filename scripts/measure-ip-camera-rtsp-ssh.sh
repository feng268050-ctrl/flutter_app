#!/usr/bin/env bash
# Measure inbound IP-camera RTSP receive bitrate on a Linux HMI board via USB-SSH/SSH.
#
# Same methodology as scripts/measure-ip-camera-rtsp.sh / measure-ip-camera-rtsp-adb.sh:
# on-device ffmpeg remux (-c copy → mpegts) size ÷ duration → Mbps.
#
# NOTE: This host helper pushes a temp ffmpeg to the board (/tmp/ffmpeg by default).
# That is out of the product HMI contract — Monitor covers / AI Vision samples use
# rootfs /usr/libexec/hmi/extract-video-frame (GStreamer), not /opt/hmi/bin/ffmpeg.
#
# Doc / acceptance: docs/ip-camera-rtsp-bitrate-android-vs-linux.md
# Healthy board (after RMII clock_in_out=input fix): remux ≥~3.3 Mbps,
# mmc_crc_delta≈0, rtp_missed≈0 (STOP_SERVICES=1).
#
# Usage:
#   scripts/measure-ip-camera-rtsp-ssh.sh
#   scripts/measure-ip-camera-rtsp-ssh.sh 15
#   SN=<product-sn> STREAMS="PR1 PR0" TRANSPORTS="udp" \
#     STOP_SERVICES=1 scripts/measure-ip-camera-rtsp-ssh.sh 12
#
# Env:
#   SN / CHIP_ID / IP     device select (same as make push-app)
#   CAMERA_IP            default 192.168.1.100
#   STREAMS              default "PR1"
#   TRANSPORTS           default "udp"
#   DURATION_S           seconds per pull (default 10; argv[1] overrides)
#   STOP_SERVICES        if 1 (default), stop hmi+mediamtx for single-consumer measure
#   APPLY_ETH0_TUNE      if 1, push/run eth0-tune.sh before measure
#   FFMPEG_HOST          host aarch64 static ffmpeg (default .cache/ffmpeg-android/ffmpeg)
#   SKIP_PUSH_FFMPEG     if 1, reuse /tmp/ffmpeg on device
#   DEBUG_LOG            optional host NDJSON path (unset = no file log)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"

CAMERA_IP="${CAMERA_IP:-192.168.1.100}"
STREAMS="${STREAMS:-PR1}"
TRANSPORTS="${TRANSPORTS:-udp}"
DURATION_S="${1:-${DURATION_S:-10}}"
STOP_SERVICES="${STOP_SERVICES:-1}"
APPLY_ETH0_TUNE="${APPLY_ETH0_TUNE:-0}"
# Optional A/B for coalesce (H-F): e.g. SET_RX_USECS=0
SET_RX_USECS="${SET_RX_USECS:-}"
FFMPEG_HOST="${FFMPEG_HOST:-$ROOT/.cache/ffmpeg-android/ffmpeg}"
DEVICE_FFMPEG="${DEVICE_FFMPEG:-/tmp/ffmpeg}"
SKIP_PUSH_FFMPEG="${SKIP_PUSH_FFMPEG:-0}"
DEBUG_LOG="${DEBUG_LOG:-}"

if ! [[ "$DURATION_S" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: DURATION_S must be a positive integer (got: $DURATION_S)" >&2
  exit 2
fi

mbps_of() {
  awk -v b="$1" -v s="$2" 'BEGIN {
    if (s <= 0) { print "0.00"; exit }
    printf "%.2f", (b * 8) / s / 1000000
  }'
}

debug_ndjson() {
  local hypothesis_id="$1" message="$2" data_json="$3"
  [[ -n "$DEBUG_LOG" ]] || return 0
  mkdir -p "$(dirname "$DEBUG_LOG")"
  local ts
  ts="$(python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null || date +%s000)"
  printf '{"sessionId":"c99d59","runId":"linux-ssh-measure","hypothesisId":"%s","location":"measure-ip-camera-rtsp-ssh.sh","message":"%s","data":%s,"timestamp":%s}\n' \
    "$hypothesis_id" "$message" "$data_json" "$ts" >>"$DEBUG_LOG"
}

remote() {
  usb_ssh_session_run_ssh "$ROOT" "$IFACE" "$@"
}

ensure_ffmpeg() {
  if [[ "$SKIP_PUSH_FFMPEG" == "1" ]]; then
    remote "test -x ${DEVICE_FFMPEG}" && return 0
    echo "ERROR: SKIP_PUSH_FFMPEG=1 but ${DEVICE_FFMPEG} missing." >&2
    return 1
  fi
  if remote "test -x ${DEVICE_FFMPEG} && ${DEVICE_FFMPEG} -version >/dev/null 2>&1"; then
    echo "==> reusing on-device ${DEVICE_FFMPEG}"
    return 0
  fi
  if [[ ! -x "$FFMPEG_HOST" ]]; then
    echo "ERROR: need aarch64 static ffmpeg at ${FFMPEG_HOST}" >&2
    echo "  (same binary as Android measure script)" >&2
    return 1
  fi
  echo "==> pushing ffmpeg → ${DEVICE_FFMPEG} (may take a minute over USB)"
  usb_ssh_session_run_scp "$ROOT" "$IFACE" "$FFMPEG_HOST" "${TARGET_USER}@${TARGET_ADDR}:${DEVICE_FFMPEG}"
  remote "chmod 755 ${DEVICE_FFMPEG} && ${DEVICE_FFMPEG} -version >/dev/null"
}

maybe_stop_services() {
  if [[ "$STOP_SERVICES" != "1" ]]; then
    echo "==> STOP_SERVICES=0 — leaving hmi running (App may hold mediamtx child)"
    remote 'systemctl is-active hmi 2>/dev/null || true; pidof mediamtx 2>/dev/null || true'
    return 0
  fi
  echo "==> stopping hmi (stops App-owned mediamtx child) for single-consumer measure"
  remote 'systemctl stop hmi 2>/dev/null || true; pkill -x mediamtx 2>/dev/null || true; sleep 1; systemctl is-active hmi 2>/dev/null || true; pidof mediamtx 2>/dev/null || true'
  # Best-effort kill leftover gst/ffmpeg consumers of camera.
  remote 'pkill -f "gst-launch|ffmpeg.*192.168.1.100|ffmpeg.*rtsp" 2>/dev/null || true'
}

maybe_apply_tune() {
  if [[ "$APPLY_ETH0_TUNE" == "1" ]]; then
    echo "==> APPLY_ETH0_TUNE=1 — pushing eth0-tune.sh and applying"
    usb_ssh_session_run_scp "$ROOT" "$IFACE" \
      "$ROOT/overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/usr/libexec/network/eth0-tune.sh" \
      "${TARGET_USER}@${TARGET_ADDR}:/tmp/"
    # Re-apply IPv4 after tune in case link was briefly disrupted.
    remote 'chmod 755 /tmp/eth0-tune.sh; mkdir -p /usr/libexec/network; cp -f /tmp/eth0-tune.sh /usr/libexec/network/; /usr/libexec/network/eth0-tune.sh eth0; /usr/libexec/network/apply-eth0.sh || true; sleep 2; echo rps=$(cat /sys/class/net/eth0/queues/rx-0/rps_cpus); echo flow=$(cat /sys/module/stmmac/parameters/flow_ctrl) wd=$(cat /sys/module/stmmac/parameters/watchdog); sysctl net.core.rmem_max net.core.netdev_max_backlog; ip -brief addr show eth0'
  fi
  if [[ -n "$SET_RX_USECS" ]]; then
    echo "==> SET_RX_USECS=${SET_RX_USECS} (ethtool -C eth0 rx-usecs …)"
    remote "ethtool -C eth0 rx-usecs ${SET_RX_USECS} 2>&1; ethtool -c eth0 2>&1 | grep -E 'rx-usecs:|rx-frames:'"
  fi
}

print_link_facts() {
  echo "==> eth0 / link / tune state"
  remote "ip -brief addr show eth0; echo -n speed=; cat /sys/class/net/eth0/speed; echo; echo -n operstate=; cat /sys/class/net/eth0/operstate; echo; echo -n rps=; cat /sys/class/net/eth0/queues/rx-0/rps_cpus 2>/dev/null; echo; sysctl net.core.rmem_max net.core.rmem_default net.core.netdev_max_backlog 2>/dev/null; echo -n rx_err=; cat /sys/class/net/eth0/statistics/rx_errors; echo -n rx_drop=; cat /sys/class/net/eth0/statistics/rx_dropped; echo -n rx_crc=; cat /sys/class/net/eth0/statistics/rx_crc_errors; echo; echo -n stmmac_flow=; cat /sys/module/stmmac/parameters/flow_ctrl 2>/dev/null; echo; echo -n stmmac_wd=; cat /sys/module/stmmac/parameters/watchdog 2>/dev/null; echo; echo -n stmmac_pause=; cat /sys/module/stmmac/parameters/pause 2>/dev/null; echo; ls /usr/libexec/network/eth0-tune.sh /etc/udev/rules.d/90-eth0-ipc-tune.rules 2>&1; cat /proc/cmdline"
  echo "==> ping ${CAMERA_IP}"
  remote "ping -c 10 -W 1 ${CAMERA_IP}" || {
    echo "ERROR: camera ${CAMERA_IP} not reachable from board eth0." >&2
    return 1
  }
  echo "==> consumers (ss)"
  remote 'ss -uap 2>/dev/null | head -20; ss -tap 2>/dev/null | grep -E "8554|554|mediamtx|ffmpeg|gst" | head -20 || true'
}

measure_one() {
  local stream="$1" transport="$2"
  local url="rtsp://${CAMERA_IP}/${stream}"
  local out="/tmp/measure-ipcam-${stream}-${transport}.ts"
  local log="/tmp/measure-ipcam-${stream}-${transport}.log"
  local host_log
  host_log="$(mktemp "${TMPDIR:-/tmp}/measure-ipcam-ssh.XXXXXX")"

  echo ""
  echo "==> measure stream=${stream} transport=${transport} duration=${DURATION_S}s"
  echo "    URL: ${url}"

  set +e
  # BusyBox/coreutils: prefer wc -c (portable). Count RTP miss + softnet/IRQ + MMC CRC deltas.
  remote "rm -f '${out}' '${log}'; \
    RXB=\$(cat /sys/class/net/eth0/statistics/rx_bytes); \
    SOFTB=\$(awk '{s+=\$1} END{print strtonum(\"0x\"\$1)+0}' /proc/net/softnet_stat 2>/dev/null || awk '{s+=strtonum(\"0x\"\$1)} END{print s+0}' /proc/net/softnet_stat); \
    DROPB=\$(awk '{s+=strtonum(\"0x\"\$2)} END{print s+0}' /proc/net/softnet_stat); \
    CRCB=\$(ethtool -S eth0 2>/dev/null | awk '\$1==\"mmc_rx_crc_error:\"{print \$2+0; exit}'); \
    UDPEB=\$(ethtool -S eth0 2>/dev/null | awk '\$1==\"mmc_rx_udp_err:\"{print \$2+0; exit}'); \
    IRQB=\$(grep eth0 /proc/interrupts | awk '{s+=\$2+\$3+\$4+\$5} END{print s+0}'); \
    START=\$(date +%s); \
    timeout $((DURATION_S + 20)) ${DEVICE_FFMPEG} -hide_banner -nostdin \
      -rtsp_transport ${transport} \
      -max_delay 5000000 \
      -i '${url}' \
      -t ${DURATION_S} \
      -c copy -f mpegts -y '${out}' \
      >'${log}' 2>&1; \
    EC=\$?; \
    END=\$(date +%s); \
    RXA=\$(cat /sys/class/net/eth0/statistics/rx_bytes); \
    SOFTA=\$(awk '{s+=strtonum(\"0x\"\$1)} END{print s+0}' /proc/net/softnet_stat); \
    DROPA=\$(awk '{s+=strtonum(\"0x\"\$2)} END{print s+0}' /proc/net/softnet_stat); \
    CRCA=\$(ethtool -S eth0 2>/dev/null | awk '\$1==\"mmc_rx_crc_error:\"{print \$2+0; exit}'); \
    UDPEA=\$(ethtool -S eth0 2>/dev/null | awk '\$1==\"mmc_rx_udp_err:\"{print \$2+0; exit}'); \
    IRQA=\$(grep eth0 /proc/interrupts | awk '{s+=\$2+\$3+\$4+\$5} END{print s+0}'); \
    BYTES=\$(wc -c < '${out}' 2>/dev/null | tr -d ' '); \
    BYTES=\${BYTES:-0}; \
    ELAPSED=\$((END-START)); \
    [ \"\$ELAPSED\" -lt 1 ] && ELAPSED=1; \
    RTP_MISSED_LINES=\$(grep -c 'RTP: missed' '${log}' 2>/dev/null || echo 0); \
    RTP_MISSED_SUM=\$(grep -Eo 'RTP: missed [0-9]+' '${log}' 2>/dev/null | awk '{s+=\$3} END{print s+0}'); \
    MAX_DELAY=\$(grep -c 'max delay reached' '${log}' 2>/dev/null || echo 0); \
    echo \"ec=\$EC bytes=\$BYTES elapsed=\$ELAPSED rx_before=\$RXB rx_after=\$RXA rtp_missed_lines=\$RTP_MISSED_LINES rtp_missed_sum=\$RTP_MISSED_SUM max_delay=\$MAX_DELAY softnet_proc_delta=\$((SOFTA-SOFTB)) softnet_drop_delta=\$((DROPA-DROPB)) irq_delta=\$((IRQA-IRQB)) mmc_crc_delta=\$((CRCA-CRCB)) mmc_udp_err_delta=\$((UDPEA-UDPEB))\"; \
    tail -n 20 '${log}'" >"$host_log"
  set -e

  local summary bytes elapsed ec mbps eth_mbps rx_before rx_after rx_delta
  local rtp_missed_lines rtp_missed_sum max_delay
  local softnet_proc_delta softnet_drop_delta irq_delta
  summary="$(grep -E '^ec=' "$host_log" | tail -1 || true)"
  if [[ -z "$summary" ]]; then
    echo "ERROR: no measurement summary from device. Raw:" >&2
    cat "$host_log" >&2 || true
    rm -f "$host_log"
    return 1
  fi
  # shellcheck disable=SC2086
  eval "${summary}"
  bytes="${bytes:-0}"
  elapsed="${elapsed:-$DURATION_S}"
  ec="${ec:-1}"
  rx_before="${rx_before:-0}"
  rx_after="${rx_after:-0}"
  rx_delta=$((rx_after - rx_before))
  [[ "$rx_delta" -lt 0 ]] && rx_delta=0
  rtp_missed_lines="${rtp_missed_lines:-0}"
  rtp_missed_sum="${rtp_missed_sum:-0}"
  max_delay="${max_delay:-0}"
  softnet_proc_delta="${softnet_proc_delta:-0}"
  softnet_drop_delta="${softnet_drop_delta:-0}"
  irq_delta="${irq_delta:-0}"
  mmc_crc_delta="${mmc_crc_delta:-0}"
  mmc_udp_err_delta="${mmc_udp_err_delta:-0}"

  mbps="$(mbps_of "$bytes" "$elapsed")"
  eth_mbps="$(mbps_of "$rx_delta" "$elapsed")"

  echo "==> result (ffmpeg remux on Linux board)"
  echo "    URL:          ${url}"
  echo "    transport:    ${transport}"
  echo "    duration:     ${elapsed}s"
  echo "    bytes:        ${bytes}"
  echo "    bitrate:      ${mbps} Mbps"
  echo "    eth0_rx_delta:${rx_delta} bytes (~${eth_mbps} Mbps wire)"
  echo "    rtp_missed:   lines=${rtp_missed_lines} sum=${rtp_missed_sum} max_delay_hits=${max_delay}"
  echo "    softnet:      proc_delta=${softnet_proc_delta} drop_delta=${softnet_drop_delta} irq_delta=${irq_delta}"
  echo "    mmc_errors:   crc_delta=${mmc_crc_delta} udp_err_delta=${mmc_udp_err_delta}"
  if [[ "$ec" != "0" || "$bytes" -le 0 ]]; then
    echo "    ffmpeg_ec:    ${ec}"
    echo "---- ffmpeg log (tail) ----"
    grep -v '^ec=' "$host_log" | tail -n 40 || true
  fi

  # H-C remux/wire gap; H-D RTP loss; H-E softnet; H-P MMC CRC under load
  debug_ndjson "HC" "ffmpeg_remux_result" \
    "{\"stream\":\"${stream}\",\"transport\":\"${transport}\",\"mbps\":${mbps},\"bytes\":${bytes},\"elapsed\":${elapsed},\"eth0_rx_mbps\":${eth_mbps},\"ffmpeg_ec\":${ec},\"rtp_missed_sum\":${rtp_missed_sum},\"rtp_missed_lines\":${rtp_missed_lines},\"max_delay_hits\":${max_delay},\"stop_services\":${STOP_SERVICES},\"apply_tune\":${APPLY_ETH0_TUNE},\"gap_mbps\":$(awk -v w="$eth_mbps" -v m="$mbps" 'BEGIN{printf "%.2f", w-m}')}"
  debug_ndjson "HD" "rtp_loss_vs_wire" \
    "{\"stream\":\"${stream}\",\"transport\":\"${transport}\",\"rtp_missed_sum\":${rtp_missed_sum},\"eth0_rx_mbps\":${eth_mbps},\"remux_mbps\":${mbps},\"rx_errors\":$(remote 'cat /sys/class/net/eth0/statistics/rx_errors' | tr -d '\r\n'),\"rx_dropped\":$(remote 'cat /sys/class/net/eth0/statistics/rx_dropped' | tr -d '\r\n')}"
  debug_ndjson "HE" "softnet_irq_delta" \
    "{\"stream\":\"${stream}\",\"transport\":\"${transport}\",\"softnet_proc_delta\":${softnet_proc_delta},\"softnet_drop_delta\":${softnet_drop_delta},\"irq_delta\":${irq_delta},\"remux_mbps\":${mbps},\"eth0_rx_mbps\":${eth_mbps}}"
  debug_ndjson "HP" "mmc_crc_udp_delta" \
    "{\"stream\":\"${stream}\",\"transport\":\"${transport}\",\"mmc_crc_delta\":${mmc_crc_delta},\"mmc_udp_err_delta\":${mmc_udp_err_delta},\"remux_mbps\":${mbps},\"eth0_rx_mbps\":${eth_mbps},\"rtp_missed_sum\":${rtp_missed_sum}}"

  echo "RESULT stream=${stream} transport=${transport} mbps=${mbps} bytes=${bytes} elapsed=${elapsed} eth0_rx_mbps=${eth_mbps} ffmpeg_ec=${ec} rtp_missed_sum=${rtp_missed_sum} max_delay=${max_delay} mmc_crc_delta=${mmc_crc_delta} mmc_udp_err_delta=${mmc_udp_err_delta}"
  rm -f "$host_log"
  [[ "$ec" == "0" && "$bytes" -gt 0 ]]
}

# --- main ---
usb_ssh_session_prepare "$ROOT"
echo "==> Linux board ${TARGET_USER}@${TARGET_ADDR} via ${TRANSPORT:-usb-ssh} IFACE=${IFACE}"
echo "    measure: camera=${CAMERA_IP} streams=${STREAMS} transports=${TRANSPORTS} duration=${DURATION_S}s"
echo ""

ensure_ffmpeg
echo ""
maybe_stop_services
echo ""
maybe_apply_tune
echo ""
print_link_facts
echo ""

# Baseline link facts into debug log (H-A: stmmac landed; H-B: tune/udev present)
rps_val="$(remote 'cat /sys/class/net/eth0/queues/rx-0/rps_cpus 2>/dev/null' | tr -d '\r\n' || true)"
rmem_val="$(remote 'sysctl -n net.core.rmem_max 2>/dev/null' | tr -d '\r\n' || true)"
flow_val="$(remote 'cat /sys/module/stmmac/parameters/flow_ctrl 2>/dev/null' | tr -d '\r\n' || true)"
wd_val="$(remote 'cat /sys/module/stmmac/parameters/watchdog 2>/dev/null' | tr -d '\r\n' || true)"
pause_val="$(remote 'cat /sys/module/stmmac/parameters/pause 2>/dev/null' | tr -d '\r\n' || true)"
cmdline_snip="$(remote 'tr " " "\n" </proc/cmdline | grep -E "^stmmac\." | tr "\n" " "' | tr -d '\r' || true)"
rx_usecs_val="$(remote 'ethtool -c eth0 2>/dev/null | awk \"/rx-usecs:/{print \\\$2; exit}\"' | tr -d '\r\n' || true)"
tune_present="$(remote 'test -x /usr/libexec/network/eth0-tune.sh && echo true || echo false' | tr -d '\r\n')"
udev_present="$(remote 'test -f /etc/udev/rules.d/90-eth0-ipc-tune.rules && echo true || echo false' | tr -d '\r\n')"
debug_ndjson "HA" "stmmac_and_tune_state" \
  "{\"flow_ctrl\":\"${flow_val}\",\"watchdog\":\"${wd_val}\",\"pause\":\"${pause_val}\",\"cmdline_stmmac\":\"${cmdline_snip}\",\"rx_usecs\":\"${rx_usecs_val}\",\"rps_cpus\":\"${rps_val}\",\"rmem_max\":\"${rmem_val}\",\"apply_tune\":${APPLY_ETH0_TUNE},\"set_rx_usecs\":\"${SET_RX_USECS:-}\",\"eth0_tune_present\":${tune_present},\"udev_rule_present\":${udev_present}}"
debug_ndjson "HF" "coalesce_state" \
  "{\"rx_usecs\":\"${rx_usecs_val}\",\"set_rx_usecs\":\"${SET_RX_USECS:-}\"}"
debug_ndjson "HB" "pre_measure_services" \
  "{\"stop_services\":${STOP_SERVICES},\"hmi\":\"$(remote 'systemctl is-active hmi 2>/dev/null' | tr -d '\r')\",\"mediamtx_pid\":\"$(remote 'pidof mediamtx 2>/dev/null' | tr -d '\r')\"}"

fail=0
for stream in $STREAMS; do
  for transport in $TRANSPORTS; do
    if ! measure_one "$stream" "$transport"; then
      fail=1
    fi
  done
done

echo ""
echo "Pass bar (docs/ip-camera-rtsp-bitrate-android-vs-linux.md): remux ≥~3.3 Mbps,"
echo "  mmc_crc_delta≈0, rtp_missed≈0 (Mac/Android ≈3.4–3.5). Low remux + high MMC CRC → RMII clock/DTS."
echo "  Low remux + MMC CRC≈0 → check MediaMTX/multi-consumer (re-run with STOP_SERVICES=1)."
exit "$fail"
