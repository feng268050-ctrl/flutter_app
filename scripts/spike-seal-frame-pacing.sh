#!/usr/bin/env bash
# E0.5 frame-pacing seal: measure present FPS for flutter-pi / eLinux DRM-GBM /
# eLinux Wayland+Weston on the same home bundle.
#
# Metrics:
#   - flutter-pi: DRM primary-plane buf flips (debug-frame-pacing.sh)
#   - eLinux:     ELINUX_PRESENT_FPS from instrumented eglSwapBuffers
#
# Usage: bash scripts/spike-seal-frame-pacing.sh [DURATION_S]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DUR="${1:-15}"
LOGFILE="${SPIKE_SEAL_LOG:-$ROOT/.cursor/embedder-seal-pacing.log}"
IFACE="${IFACE:-en12}"
ADDR="${USB_SSH_ADDR:-192.168.55.1}"
USER_="${USB_SSH_USER:-root}"
PASS="${USB_SSH_PASS:-rockchip}"
REMOTE=/userdata/elinux-spike

SSH() {
  sshpass -p "$PASS" ssh \
    -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new \
    -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    -o PreferredAuthentications=password -o PubkeyAuthentication=no \
    -o BindInterface="$IFACE" -o ServerAliveInterval=3 -o ServerAliveCountMax=3 \
    "$USER_@$ADDR" "$@"
}

kill_all_flutter() {
  SSH 'systemctl stop hmi.service 2>/dev/null || true
    for f in /userdata/elinux-spike/*.pid; do
      [ -f "$f" ] || continue
      kill -9 "$(cat "$f")" 2>/dev/null || true
      rm -f "$f"
    done
    # No pkill on this rootfs — use killall (matches argv0 prefix OK on BusyBox).
    true # flutter-pi removed 2>/dev/null || true
    killall -9 flutter-drm-gbm-backend 2>/dev/null || true
    killall -9 flutter-wayland-client 2>/dev/null || true
    killall -9 weston 2>/dev/null || true
    # Truncated comm fallback (TASK_COMM_LEN=16).
    killall -9 flutter-drm-gbm-b 2>/dev/null || true
    killall -9 flutter-wayland- 2>/dev/null || true
    sleep 1
    left=""
    for p in flutter-pi flutter-drm-gbm-backend flutter-wayland-client weston flutter-drm-gbm-b; do
      ids=$(pidof "$p" 2>/dev/null || true)
      [ -n "$ids" ] && left="$left $p:$ids"
    done
    if [ -n "$left" ]; then
      echo "ERROR: lingering clients:$left" >&2
      exit 1
    fi
  '
}

ensure_icudtl() {
  SSH 'if [[ ! -e /opt/hmi/data/icudtl.dat ]]; then
      mkdir -p /opt/hmi/data
      cp -L /usr/share/flutter/release/data/icudtl.dat /opt/hmi/data/icudtl.dat
    fi'
}

push_bins() {
  local gbm="$ROOT/.cache/elinux-spike/out-drm-gbm/flutter-drm-gbm-backend"
  local wl="$ROOT/.cache/elinux-spike/out-wayland/flutter-wayland-client"
  [[ -x "$gbm" ]] || { echo "ERROR: missing $gbm — build DRM-GBM spike first" >&2; exit 1; }
  [[ -x "$wl" ]] || { echo "ERROR: missing $wl — build Wayland spike first" >&2; exit 1; }
  SSH "mkdir -p '$REMOTE'"
  SSH "cat > '$REMOTE/flutter-drm-gbm-backend' && chmod +x '$REMOTE/flutter-drm-gbm-backend'" <"$gbm"
  SSH "cat > '$REMOTE/flutter-wayland-client' && chmod +x '$REMOTE/flutter-wayland-client'" <"$wl"
  SSH "cat > /etc/xdg/weston/weston.ini" <"$ROOT/scripts/spike-weston.ini"
  # Neutralize desktop locking drop-in for spike.
  SSH 'mkdir -p /etc/xdg/weston/weston.ini.d
    printf "[shell]\nlocking=false\n" > /etc/xdg/weston/weston.ini.d/02-desktop.ini'
}

sample_drm_flips() {
  local run_id="$1"
  bash "$ROOT/scripts/debug-frame-pacing.sh" "$run_id" "$DUR" >/dev/null
}

sample_elinux_present_fps() {
  # Poll remote log for ELINUX_PRESENT_FPS lines for DUR seconds after a warmup.
  local remote_log="$1"
  local out_tag="$2"
  sleep 2
  SSH "truncate -s 0 '$remote_log.fps' 2>/dev/null || true
    # Copy only FPS lines from the live log for DUR seconds.
    : > '$remote_log.fps'
    end=\$(( \$(date +%s) + $DUR ))
    while [ \$(date +%s) -lt \$end ]; do
      grep '^ELINUX_PRESENT_FPS ' '$remote_log' 2>/dev/null | tail -n 1 >> '$remote_log.fps.tmp' || true
      sleep 1
    done
    # Prefer unique per-second samples from the raw log over the poll file.
    grep '^ELINUX_PRESENT_FPS ' '$remote_log' 2>/dev/null | tail -n $((DUR + 3)) > '$remote_log.fps' || true
    wc -l '$remote_log.fps'
    cat '$remote_log.fps'
  " | tee -a "$LOGFILE" | sed "s/^/[$out_tag] /"
}

restore_hmi() {
  kill_all_flutter
  SSH 'systemctl start hmi.service; sleep 3; systemctl is-active hmi.service; pidof flutter-pi'
}

mkdir -p "$(dirname "$LOGFILE")"
: >"$LOGFILE"
echo "=== embedder frame-pacing seal $(date -u +%Y-%m-%dT%H:%M:%SZ) dur=${DUR}s ===" | tee -a "$LOGFILE"

echo "[seal] binaries ready (set SPIKE_SEAL_REBUILD=1 to force rebuild)"
if [[ "${SPIKE_SEAL_REBUILD:-0}" == "1" ]]; then
  echo "[seal] rebuilding instrumented spikes ..."
  ENABLE_VSYNC=ON bash "$ROOT/scripts/spike-elinux-drm-gbm.sh" build
  ENABLE_VSYNC=ON bash "$ROOT/scripts/spike-elinux-wayland.sh" build
fi
push_bins
ensure_icudtl

echo "[seal] --- A: flutter-pi (DRM flips) ---" | tee -a "$LOGFILE"
restore_hmi
sample_drm_flips "seal-pi"

echo "[seal] --- B: eLinux DRM-GBM — SKIP (EGL_BAD_DISPLAY under wayland-gbm Mali; B already rejected) ---" | tee -a "$LOGFILE"

echo "[seal] --- C: Weston + eLinux Wayland (ELINUX_PRESENT_FPS) ---" | tee -a "$LOGFILE"
kill_all_flutter
SSH "systemctl stop hmi.service 2>/dev/null || true
  mkdir -p /run/user/0; chmod 700 /run/user/0
  rm -f '$REMOTE/weston.log' '$REMOTE/wayland-run.log'
  # Client owns rotation; weston.ini transform=rotate-90 may double-rotate —
  # use no-transform core for this seal (rewrite ini without [output]).
  cat > /etc/xdg/weston/weston.ini <<'EOF'
[core]
backend=drm-backend.so
shell=kiosk-shell.so
idle-time=0

[shell]
locking=false
animation=none
startup-animation=none
EOF
  nohup env XDG_RUNTIME_DIR=/run/user/0 \
    weston --backend=drm-backend.so --shell=kiosk-shell.so --idle-time=0 \
    >'$REMOTE/weston.log' 2>&1 &
  echo \$! >'$REMOTE/weston.pid'
  sleep 2
  kill -0 \$(cat '$REMOTE/weston.pid')
  nohup env XDG_RUNTIME_DIR=/run/user/0 WAYLAND_DISPLAY=wayland-0 \
    '$REMOTE/flutter-wayland-client' --bundle=/opt/hmi --fullscreen --rotation=90 \
    >'$REMOTE/wayland-run.log' 2>&1 &
  echo \$! >'$REMOTE/wayland-run.pid'
  sleep 3
  kill -0 \$(cat '$REMOTE/wayland-run.pid')
  echo weston=\$(pidof weston) client=\$(pidof flutter-wayland-client)
  tail -8 '$REMOTE/wayland-run.log' || true
"
sample_elinux_present_fps "$REMOTE/wayland-run.log" "wayland"

echo "[seal] restoring hmi ..." | tee -a "$LOGFILE"
restore_hmi

python3 - <<'PY' | tee -a "$LOGFILE"
import json, re, statistics, pathlib
root = pathlib.Path("/Users/ayon/Workspace/lws-hmi")
drm_log = root / ".cursor/debug-8fb78d.log"
seal_log = pathlib.Path(__import__("os").environ.get(
    "SPIKE_SEAL_LOG", str(root / ".cursor/embedder-seal-pacing.log")))

def drm_avg(run_id):
    rows = []
    if not drm_log.exists():
        return None
    for line in drm_log.read_text().splitlines():
        if not line.startswith("{"):
            continue
        try:
            o = json.loads(line)
        except Exception:
            continue
        if o.get("runId") == run_id and o.get("message") == "bucket":
            rows.append(o["data"]["flips"])
    if len(rows) < 3:
        return None
    mid = rows[1:-1]
    return {
        "avg": sum(mid) / len(mid),
        "min": min(mid),
        "max": max(mid),
        "n": len(mid),
        "samples": mid,
    }

def parse_present_from_seal(tag):
    # Accept both "[wayland] ELINUX_PRESENT_FPS N" and bare "ELINUX_PRESENT_FPS N"
    # after the C section header in the seal log.
    vals = []
    text = seal_log.read_text() if seal_log.exists() else ""
    in_section = tag == "gbm"  # gbm section may be absent
    section_re = re.compile(rf"--- C:.*Wayland" if tag == "wayland" else rf"--- B:.*DRM-GBM")
    for line in text.splitlines():
        if "--- C:" in line and "Wayland" in line:
            in_section = tag == "wayland"
        if "--- B:" in line and "DRM-GBM" in line:
            in_section = tag == "gbm"
        if "--- A:" in line or "restoring hmi" in line or "SEAL SUMMARY" in line:
            if tag == "wayland" and "--- A:" in line:
                pass
            if "restoring hmi" in line or "SEAL SUMMARY" in line:
                in_section = False if tag == "wayland" else in_section
        if tag == "wayland" and not in_section and "--- C:" not in line:
            # Also accept prefixed lines anywhere
            pass
        m = re.search(r"ELINUX_PRESENT_FPS\s+(\d+)", line)
        if not m:
            continue
        if tag == "wayland" and ("[wayland]" in line or in_section or "ELINUX_PRESENT_FPS" in line):
            # Prefer lines near wayland tag; collect all FPS after C header via in_section
            if "[wayland]" in line or in_section:
                vals.append(int(m.group(1)))
        elif tag == "gbm" and ("[gbm]" in line or in_section):
            vals.append(int(m.group(1)))
    vals = [v for v in vals if v > 0]
    if len(vals) < 3:
        # Fallback: any ELINUX_PRESENT_FPS in whole log when only one eLinux run
        if tag == "wayland":
            vals = [int(m.group(1)) for m in re.finditer(r"ELINUX_PRESENT_FPS\s+(\d+)", text)]
            vals = [v for v in vals if v > 0]
    if len(vals) < 3:
        return None
    mid = vals[1:-1] if len(vals) > 3 else vals
    return {
        "avg": sum(mid) / len(mid),
        "min": min(mid),
        "max": max(mid),
        "n": len(mid),
        "samples": mid,
    }

pi = drm_avg("seal-pi")
gbm_present = parse_present_from_seal("gbm")
gbm_drm = drm_avg("seal-gbm-drm")
wl_present = parse_present_from_seal("wayland")

GATE = 50.0

def fmt(d, label):
    if not d:
        return f"{label}: NO DATA"
    ok = "PASS" if d["avg"] >= GATE else "FAIL"
    return (f"{label}: avg={d['avg']:.1f} min={d['min']} max={d['max']} "
            f"n={d['n']} → {ok} (gate>={GATE:.0f})")

print("=== SEAL SUMMARY ===")
print(fmt(pi, "A flutter-pi DRM flips"))
print(fmt(gbm_present, "B eLinux DRM-GBM present"))
print(fmt(gbm_drm, "B eLinux DRM-GBM DRM flips (xcheck)"))
print(fmt(wl_present, "C eLinux Wayland+Weston present"))

# Decision helper
def avg(d):
    return d["avg"] if d else None

c_avg = avg(wl_present)
b_avg = avg(gbm_present)
a_avg = avg(pi)
print("---")
if c_avg is not None and c_avg >= GATE:
    print("DECISION: C PASSES gate → lock scheme C")
elif c_avg is not None and b_avg is not None and c_avg > b_avg + 5 and c_avg > (a_avg or 0) + 5:
    print(f"DECISION: C improves vs A/B but below gate ({c_avg:.1f}<{GATE:.0f}) → continue C + tune")
elif c_avg is not None:
    print(f"DECISION: C present avg={c_avg:.1f} below gate → investigate / consider R6")
else:
    print("DECISION: incomplete data — inspect logs")
PY
