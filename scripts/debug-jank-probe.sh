#!/usr/bin/env bash
# #region agent log — DEBUG INSTRUMENTATION (session 8fb78d), safe to delete
# Host-side jank probe: SSH into the ynh960 board, sample hardware telemetry at
# high frequency while the user reproduces animation jank, and append one NDJSON
# line per sample to the debug session log. Discriminates these hypotheses:
#   H1 CPU clamped at 1104 MHz + CPU-bound raster/ui -> frame deadline misses
#   H2 flutter-pi raster NOT saturated but frames drop -> vsync/DRM page-flip stall
#   H3 Goodix gt9xx IRQ report rate too low/bursty during touch -> scroll stutter
#   H4 deep cpu-sleep idle re-entered on some cores -> wake-latency jank
#   H5 gpu/dmc devfreq drops during animation
#
# Usage: bash scripts/debug-jank-probe.sh [RUN_ID] [DURATION_S] [INTERVAL_MS]
set -u

RUN_ID="${1:-run1}"
DURATION_S="${2:-40}"
INTERVAL_MS="${3:-200}"

IFACE="${IFACE:-en12}"
ADDR="${LWS_HMI_USB_SSH_ADDR:-192.168.55.1}"
USER_="${LWS_HMI_USB_SSH_USER:-root}"
PASS="${LWS_HMI_USB_SSH_PASS:-rockchip}"
LOGFILE="/Users/ayon/Workspace/lws-hmi/.cursor/debug-8fb78d.log"

SSH() {
  sshpass -p "$PASS" ssh \
    -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new \
    -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    -o PreferredAuthentications=password -o PubkeyAuthentication=no \
    -o BindInterface="$IFACE" \
    -o ServerAliveInterval=3 -o ServerAliveCountMax=3 \
    "$USER_@$ADDR" "$@"
}

echo "[jank-probe] checking device reachability ($USER_@$ADDR via $IFACE)..." >&2
if ! SSH 'echo ok' >/dev/null 2>&1; then
  echo "[jank-probe] ERROR: board unreachable. Re-plug USB, run 'make usb-ssh-setup', then retry." >&2
  exit 1
fi

echo "[jank-probe] starting ${DURATION_S}s sampling (run=$RUN_ID, every ${INTERVAL_MS}ms)." >&2
echo "[jank-probe] >>> REPRODUCE THE JANK NOW: swipe/scroll/trigger the animation continuously <<<" >&2

# The device program: emit one NDJSON sample line per interval to stdout.
SSH 'sh -s' "$RUN_ID" "$DURATION_S" "$INTERVAL_MS" <<'DEVEOF' >>"$LOGFILE"
RUN="$1"; DUR="$2"; IVL_MS="$3"; SID="8fb78d"
mount -t debugfs none /sys/kernel/debug 2>/dev/null

PID=$(pidof flutter-pi | awk '{print $1}')
UITID=""; RASTID=""
if [ -n "$PID" ]; then
  for t in /proc/$PID/task/*; do
    c=$(cat "$t/comm" 2>/dev/null)
    case "$c" in
      io.flutter.ui) UITID=${t##*/} ;;
      io.flutter.rast) RASTID=${t##*/} ;;
    esac
  done
fi

read_clk() {
  for f in /sys/kernel/debug/clk/clk_scmi_cpu/clk_rate /sys/kernel/debug/clk/armclk/clk_rate; do
    if [ -r "$f" ]; then cat "$f" 2>/dev/null; return; fi
  done
  awk '/ armclk /{print $4; exit}' /sys/kernel/debug/clk/clk_summary 2>/dev/null
}

thr_j() {  # $1=tid -> utime+stime jiffies
  if [ -z "$1" ] || [ ! -r "/proc/$PID/task/$1/stat" ]; then echo 0; return; fi
  awk '{print $14+$15}' "/proc/$PID/task/$1/stat" 2>/dev/null
}

ITERS=$(( DUR * 1000 / IVL_MS ))
SLEEP_S=$(awk "BEGIN{printf \"%.3f\", $IVL_MS/1000}")
i=0
while [ "$i" -lt "$ITERS" ]; do
  t_up=$(awk '{printf "%d", $1*1000}' /proc/uptime)
  ts=$(( $(date +%s) * 1000 ))
  armclk=$(read_clk); [ -n "$armclk" ] || armclk=0
  gpu=$(cat /sys/class/devfreq/fde60000.gpu/cur_freq 2>/dev/null); [ -n "$gpu" ] || gpu=0
  dmc=$(cat /sys/class/devfreq/dmc/cur_freq 2>/dev/null); [ -n "$dmc" ] || dmc=0
  set -- $(head -1 /proc/stat)
  # $1=cpu $2=user $3=nice $4=system $5=idle $6=iowait $7=irq $8=softirq ...
  cpu_idle=$(( $5 + $6 ))
  cpu_total=$(( $2 + $3 + $4 + $5 + $6 + $7 + $8 + ${9:-0} ))
  gt9=$(awk '/gt9xx/{print $2+$3+$4+$5; exit}' /proc/interrupts 2>/dev/null); [ -n "$gt9" ] || gt9=0
  sleep_sum=0
  for c in 0 1 2 3; do
    u=$(cat /sys/devices/system/cpu/cpu$c/cpuidle/state1/usage 2>/dev/null || echo 0)
    sleep_sum=$(( sleep_sum + u ))
  done
  rast_j=$(thr_j "$RASTID"); ui_j=$(thr_j "$UITID")
  printf '{"sessionId":"%s","runId":"%s","hypothesisId":"multi","location":"jank-probe:device","message":"sample","timestamp":%s,"data":{"t_up_ms":%s,"armclk":%s,"gpu":%s,"dmc":%s,"cpu_total":%s,"cpu_idle":%s,"gt9irq":%s,"cpu_sleep":%s,"rast_j":%s,"ui_j":%s,"pid":"%s","rast_tid":"%s","ui_tid":"%s"}}\n' \
    "$SID" "$RUN" "$ts" "$t_up" "$armclk" "$gpu" "$dmc" "$cpu_total" "$cpu_idle" "$gt9" "$sleep_sum" "$rast_j" "$ui_j" "$PID" "$RASTID" "$UITID"
  i=$(( i + 1 ))
  sleep "$SLEEP_S" 2>/dev/null || sleep 1
done
DEVEOF

echo "[jank-probe] done. Samples appended to $LOGFILE" >&2
# #endregion
