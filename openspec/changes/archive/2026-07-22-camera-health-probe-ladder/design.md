## Context

`LinuxIpCameraController` owns periodic health via injectable `IpCameraProbe` (default: `ping -c 1`). Product session brings up eth0 path + MediaMTX, which **exclusively** pulls camera `/PR0` and `/PR1` (single-client streams). C002 and Monitor Camera Comm Status already subscribe to `IpCameraHealth`; they must keep working while we change how healthy/unhealthy is decided.

Operators care about false C002 and about not kicking MediaMTX off PR0/PR1. Therefore implementation is **validate-first**: each probe rung is proven on ynh960 + the real camera before it becomes the production default.

## Goals / Non-Goals

**Goals:**

- A probe strategy that is cheaper / more RTSP-relevant than unconditional ICMP, without stealing PR0/PR1.
- Preserve health Stream API, debounce thresholds, quiet windows, and C002 wiring.
- Ladder of candidates with explicit pass/fail validation gates before locking the default.

**Non-Goals:**

- Changing MediaMTX topology or allowing a second consumer on `/PR0`/`/PR1`.
- Using DESCRIBE+SETUP/PLAY on native PR paths as a health check.
- Redesigning C002 policy, LaserWorkGuard, or Alarm Logs.
- Guaranteeing “picture quality” (bitrate/CRC) — only connectivity / service liveness.

## Decisions

### 1. Hard rule: never occupy PR0/PR1 for health

**Choice:** Any active probe MUST NOT send RTSP `SETUP`/`PLAY` (or equivalent) to `/PR0` or `/PR1`. Short TCP to port 554 and RTSP `OPTIONS` (session-level, no media SETUP) are allowed only after validation.

**Why:** Camera firmware enforces one client per stream; MediaMTX is that client.

**Rejected:** Periodic DESCRIBE of `/PR0` as health — high risk of counting as a consumer or racing MediaMTX.

### 2. Validate-then-lock ladder (order of attempt)

Try rungs in order; **stop at the first rung that passes device criteria** and lock it as default (others remain injectable/debug):

| Order | Rung | What it proves | Pass criteria (sketch) |
|------:|------|----------------|------------------------|
| 1 | **Relay/path-informed** | When MediaMTX upstream is up, use session readiness + optional light host check; avoid extra camera clients | No C002 flap while preview/relay stable; disconnect camera → unhealthy within debounce; reconnect → healthy; MediaMTX stays on PR0 |
| 2 | **TCP :554 short connect** | RTSP port accepts TCP | Same flap/disconnect tests; no MediaMTX disconnect when probe runs every 1s |
| 3 | **RTSP OPTIONS** | RTSP stack answers without media session | Same; OPTIONS must not allocate PR0/PR1 |
| 4 | **ICMP** (baseline) | Host reachable | Keep as fallback if 1–3 fail validation or for host/stub |

**Why this order:** Prefer zero/low camera load and semantic closeness to “link usable,” escalate only when evidence fails.

### 3. Where composition lives

**Choice:** Keep **HAL** owning the periodic timer + debounce + `IpCameraProbe` injection. Product session MAY:

- Pass a composed probe into the controller, and/or
- Call `suspendProbes` / feed readiness by temporarily relying on path events — without a second App-owned ICMP timer.

Prefer: HAL default becomes the locked rung (e.g. TCP); product optionally wraps with “if relay reports upstream dead → fail fast” without opening a second stream.

**Rejected:** App-only Timer duplicating HAL health (already forbidden by `ip-camera` spec).

### 4. API surface

**Choice:** Extend probe injection (and optionally a small `IpCameraProbeKind` / factory) rather than changing `Stream<IpCameraHealth>` shape. C002 adapters stay untouched.

### 5. Validation before code default flip

**Choice:** Tasks require **device evidence** for each rung (journal + MediaMTX still pulling + no spurious C002) before marking that rung as production default. Implementation may land helpers behind flags/injection first.

**Locked (2026-07-22, ynh960 + camera 192.168.1.100):** Rung 1 failed (no MediaMTX upstream readiness API — only `systemctl is-active`). Rung 2 **TCP :554** passed burst + live MediaMTX coexistence → production default `tcpRtspPortProbe()`. OPTIONS left injectable (on-device OPTIONS unreliable on this SKU). ICMP remains injectable fallback. Evidence: `notes-validation.md`.

## Risks / Trade-offs

- **[Risk]** Some cameras count any TCP to 554 toward connection limits → **Mitigation:** validate under MediaMTX load; fall back to ICMP or OPTIONS; keep connect short-lived.
- **[Risk]** OPTIONS implementation varies → **Mitigation:** treat non-2xx / timeout as fail; if OPTIONS breaks a camera, skip rung.
- **[Risk]** Relay-informed health lags true host death if MediaMTX caches → **Mitigation:** combine with a light host probe or timeout on upstream silence; document in validation.
- **[Risk]** ICMP still needed on stub/host → **Mitigation:** keep ICMP probe for non-Linux product paths / tests.

## Migration Plan

1. Add probe implementations + unit tests (fake sockets / fake OPTIONS).
2. Device-validate rung 1 → 2 → 3 → 4; record which first passes.
3. Set that rung as Linux default; leave others injectable.
4. Regression: C002, Camera Comm Status, preview/record still work.
5. Rollback: revert default probe to ICMP via one-line factory change.

## Open Questions

- ~~Exact MediaMTX signal for “upstream dead” available on board today~~ — **Resolved:** none beyond `systemctl is-active`; rung 1 failed validation.
- ~~Camera RTSP port always 554 for this SKU~~ — **Resolved:** 554 confirmed during TCP rung; `kDefaultIpCameraRtspPort`.
