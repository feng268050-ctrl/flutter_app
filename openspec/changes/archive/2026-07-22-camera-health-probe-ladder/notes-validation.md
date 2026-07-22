# Device validation notes — camera-health-probe-ladder

Board: USB-SSH `baaaf748631f2489` (ynh960 line), camera `192.168.1.100`.
Date: 2026-07-22. MediaMTX + HMI both `active`; journal shows ongoing PR0/PR1 RTSP source (RTP loss warnings = still sourcing; eth0 path is lossy in this lab).

## Rung 1 — relay / path-informed — **FAIL** (skip as production)

- Available signals: `path.ok`, `relayStatus.phase==running` (`systemctl is-active mediamtx` only).
- **No** MediaMTX HTTP/API / path-ready / upstream-track signal in product code.
- Composition cannot prove “MediaMTX still holds PR0” vs “unit up but source dead” without an extra camera client.
- Keep `relayInformedProbe` injectable for future cameras / if API is added later.

## Rung 2 — TCP :554 short-connect — **PASS** (locked default)

Evidence:

| Check | Result |
|-------|--------|
| TCP while MediaMTX pulling PR0/PR1 | OK (`nc -z` / `/dev/tcp`; burst 60/60) |
| HAL default = `tcpRtspPortProbe()` after `make build-app` + `make push-app` | Deployed |
| HAL-only soak ≥10 min | MediaMTX stayed `active`; **no competing shell probes** |
| False C002 (HAL-only 10m) | 2 episodes (~t=2m, ~t=6m); each = one rising + UI WARN_DBG lines. Lab eth0 already shows heavy RTP loss; pre-change ICMP also flapped. Competing parallel `/dev/tcp` loops **amplify** flaps — do not run shell TCP soak alongside HAL. |
| Blackhole `ip route blackhole 192.168.1.100` | TCP blocked; C002 rose within debounce window; after `ip route del` + ~20s, HMI+MediaMTX `active` |
| SETUP/PLAY on PR0/PR1 | Not used (TCP close only) |

Production default: `LinuxIpCameraController` → `tcpRtspPortProbe()` (port **554** confirmed for this SKU).

## Rung 3 — RTSP OPTIONS — skipped (TCP won)

- On-device OPTIONS via `/dev/tcp` got empty/reset responses (no reliable RTSP status line).
- Helper remains injectable; not production default on this SKU.

## Rung 4 — ICMP — fallback only

- Still available as `icmpIpCameraProbe`; previous default; not production default after TCP lock.

## App wiring

- No second App health Timer; product session uses HAL controller default probe (`probe:` optional override only).
- No relay wrap required for locked TCP rung.
