#!/usr/bin/env bash
# #region agent log — DEBUG INSTRUMENTATION (session 8fb78d), safe to delete
# Frame-pacing probe: per-second, compares VOP2 vblank IRQ rate (ground-truth
# panel refresh) against Weston/eLinux present rate (actual presented fps, via
# win0 framebuffer-address changes in the DRM debugfs summary). Reveals whether
# embedder is missing vblanks (H2a) vs the panel simply running at 56 Hz (H2b).
#
# Usage: bash scripts/debug-frame-pacing.sh [RUN_ID] [DURATION_S]
set -u
RUN_ID="${1:-pacing1}"
DURATION_S="${2:-25}"
IFACE="${IFACE:-en12}"
ADDR="${USB_SSH_ADDR:-192.168.55.1}"
USER_="${USB_SSH_USER:-root}"
PASS="${USB_SSH_PASS:-rockchip}"
LOGFILE="/Users/ayon/Workspace/lws-hmi/.cursor/debug-8fb78d.log"

SSH() {
  sshpass -p "$PASS" ssh \
    -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new \
    -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    -o PreferredAuthentications=password -o PubkeyAuthentication=no \
    -o BindInterface="$IFACE" -o ServerAliveInterval=3 -o ServerAliveCountMax=3 \
    "$USER_@$ADDR" "$@"
}

echo "[frame-pacing] checking device ($USER_@$ADDR via $IFACE)..." >&2
if ! SSH 'echo ok' >/dev/null 2>&1; then
  echo "[frame-pacing] ERROR: board unreachable. Re-plug USB, 'make setup-usb-ssh', retry." >&2
  exit 1
fi
echo "[frame-pacing] sampling ${DURATION_S}s. >>> REPRODUCE THE JANK NOW (animate continuously) <<<" >&2

SSH 'sh -s' "$RUN_ID" "$DURATION_S" <<'DEVEOF' >>"$LOGFILE"
RUN="$1"; DUR="$2"; SID="8fb78d"
mount -t debugfs none /sys/kernel/debug 2>/dev/null
vop_irq(){ awk '$1=="45:"{print $2+$3+$4+$5}' /proc/interrupts; }
gpu_irq(){ awk '$1 ~ /^(98|99|100):$/ {for(i=2;i<=5;i++) s+=$i} END{print s+0}' /proc/interrupts; }
buf(){ awk '/buf\[0\]/{print $3; exit}' /sys/kernel/debug/dri/0/summary; }
sec=$(date +%s); END=$(( sec + DUR ))
flips=0; reads=0; prev=""; vop0=$(vop_irq); gpu0=$(gpu_irq); iters=0
gap=0; maxgap=0
# Sample framebuffer at full loop speed; only fork date/read interrupts every
# 32 iterations to keep buf sampling well above 2x the 56 Hz refresh.
while :; do
  a=$(buf)
  gap=$(( gap + 1 ))
  if [ "$a" != "$prev" ]; then
    flips=$(( flips + 1 )); prev=$a
    [ "$gap" -gt "$maxgap" ] && maxgap=$gap
    gap=0
  fi
  reads=$(( reads + 1 )); iters=$(( iters + 1 ))
  if [ $(( iters & 31 )) -eq 0 ]; then
    now=$(date +%s)
    if [ "$now" != "$sec" ]; then
      vop1=$(vop_irq); gpu1=$(gpu_irq)
      gutil=$(cat /sys/devices/platform/fde60000.gpu/utilisation 2>/dev/null); [ -n "$gutil" ] || gutil=-1
      t_up=$(awk '{printf "%d",$1*1000}' /proc/uptime)
      printf '{"sessionId":"%s","runId":"%s","hypothesisId":"H2","location":"frame-pacing:device","message":"bucket","timestamp":%s,"data":{"t_up_ms":%s,"flips":%s,"reads":%s,"vop_irq":%s,"gpu_irq":%s,"gpu_util":%s,"maxgap":%s}}\n' \
        "$SID" "$RUN" "$(( now*1000 ))" "$t_up" "$flips" "$reads" "$(( vop1 - vop0 ))" "$(( gpu1 - gpu0 ))" "$gutil" "$maxgap"
      vop0=$vop1; gpu0=$gpu1; sec=$now; flips=0; reads=0; maxgap=0
    fi
    [ "$now" -ge "$END" ] && break
  fi
done
DEVEOF
echo "[frame-pacing] done -> $LOGFILE" >&2
# #endregion
