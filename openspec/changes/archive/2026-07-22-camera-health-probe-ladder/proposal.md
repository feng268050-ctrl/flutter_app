## Why

IP-camera health today is ICMP ping only. That is safe for exclusive PR0/PR1 stream slots, but forks a process every second, can disagree with “can we use RTSP,” and does not reuse MediaMTX/path signals the product already has. We need a better probe ladder that stays accurate without stealing the camera’s single-client PR0/PR1 consumers.

## What Changes

- Replace (or demote) default ICMP-only probing with a **validate-then-lock** ladder of connectivity checks.
- Hard constraint: probes MUST NOT `SETUP`/`PLAY` (or otherwise occupy) native `/PR0` or `/PR1` while MediaMTX (or any product upstream) holds those streams.
- Candidate probes, tried in order until device evidence is stable with no false C002 / no stream steal:
  1. Prefer **MediaMTX / path / relay readiness** when the product session already has a live upstream (no extra camera client).
  2. Short **TCP connect to RTSP port** (default 554) with immediate close — port liveness only.
  3. Lightweight **RTSP OPTIONS** (no stream path SETUP/PLAY) if TCP alone is insufficient on the target camera.
  4. Keep **ICMP** as last-resort / debug baseline if higher rungs fail validation.
- Preserve existing health phases (`unknown` / `healthy` / `unhealthy`), consecutive OK/fail debounce, configure quiet windows, and C002 / Camera Comm Status consumers (same `IpCameraHealth` Stream).
- Document the locked-in default probe after device validation; do not ship an unvalidated probe as production default.

## Capabilities

### New Capabilities

- _(none)_ — behavior stays under existing IP-camera health.

### Modified Capabilities

- `ip-camera`: HAL health sampling may use an injectable probe ladder beyond ICMP; MUST NOT consume exclusive PR0/PR1 stream clients; product session MAY feed relay/path readiness into health without a second App ICMP timer.
- `camera-communication-alarm`: C002 remains driven by HAL `IpCameraHealth`; clarify that unhealthy MUST NOT be caused by probes that steal PR0/PR1 from MediaMTX.

## Impact

- `packages/cyber_hal` `LinuxIpCameraController` / `IpCameraProbe` (and possibly a small probe helper).
- Product `IpCameraProductSession` / MediaMTX relay readiness signals (optional feed into HAL or App-composed health — design chooses one without forking C002).
- Device validation scripts/notes for ladder rungs; Monitor Camera Comm Status and C002 behavior unchanged at the Stream API.
- No Buildroot package change expected unless a new CLI tool is introduced (prefer Dart `Socket` / minimal RTSP text, not `ping`).
