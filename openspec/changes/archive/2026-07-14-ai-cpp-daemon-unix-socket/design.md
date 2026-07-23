## Context

Product AI today runs in-process via `libai.so` + JNI (`AiManager`, `NativeStreamDetectCoordinator`, StreamDetect uplink callback). Crashes in decode/detect take down the HMI. Architecture and contract are defined in `docs/ai-cpp-daemon-unix-socket-design.md` (2026-07-14). This change implements that design so C++ AI can run as an independent daemon; P0 is the first apply exit (“能够独立运行”).

Locked product decisions (from design doc):

- Whole-package AI moves into the daemon; Java retains Modbus, settings, MediaMTX, UI/alerts/upload, supervision.
- Laser gate is **only** `machineStatusSeg1` Bit0 (`DeviceStatus.isLaserOn()`), not `LaserEnableStateHolder`.
- Cold-start spawn, resident process, Java restart on exit/crash.
- Target: Unix socket replaces JNI; no long-lived dual-run feature flag.

## Goals / Non-Goals

**Goals:**

1. Ship `lws_ai_daemon` as a packageable native executable that can listen on `cmd.sock` / `evt.sock`, emit heartbeat / `daemon_ready`, and survive as a child of the App.
2. Java `AiDaemonSupervisor` spawns/restarts the daemon, reconnects sockets, re-pushes laser + AI assist config, and cleans up on terminate.
3. Document and implement JSON Lines protocol v1 enough for P0 (ping, heartbeat, ready, laser_state, ai_assist_config stubs, shutdown) and leave cmd/evt types for P1+ wired or stubbed consistently.
4. Keep algorithm libraries buildable so P1 can move StreamDetect into the daemon without redesigning IPC.

**Non-Goals:**

- Implementing Modbus or MediaMTX inside C++.
- Completing P2/P3 (offline cmds / full JNI removal) in the first apply pass—those remain tasks with clear gates but may land in follow-up apply sessions.
- Long-term product toggle that runs JNI StreamDetect and daemon StreamDetect concurrently.

## Decisions

### D1 — Two SOCK_STREAM sockets + JSON Lines

- **Choice**: `cmd.sock` (Java client → daemon server, req/resp with `id`) and `evt.sock` (daemon publishes; Java subscribes). Framing: one UTF-8 JSON object + `\n`. Common fields: `v=1`, `type`, optional `id`, `ts_ms`.
- **Why**: Matches design doc; simple to debug with `socat`/logcat; avoids Protobuf codegen tax for HMI.
- **Alternatives**: Single multiplexed socket (harder backpressure split); gRPC UDS (heavier on Android NDK footprint).

### D2 — Daemon binary name and layout

- **Choice**: Binary `lws_ai_daemon`; workdir `{files}/lens_guard/` (existing); sock dir `{files}/ai_daemon/` (`cmd.sock`, `evt.sock`).
- **Why**: Aligns with design doc and existing OpenCV/config layout.
- **Packaging**: Prefer copy/extract to app-private executable path from APK native libs/assets; validate `execute` on RK3566 (SELinux / `nativeLibraryDir` quirks). Fall back documented in tasks if direct `jniLibs` exec fails.

### D3 — P0 minimal logic inside daemon

- **Choice**: P0 ships process + IPC + heartbeat + ack path for `laser_state` / `ai_assist_config` / `ping` / `shutdown`, storing last known gate state. StreamDetect PLAY / detect modules may still be stubbed until P1 links existing `stream_detect_*` into the daemon process.
- **Why**: Proves independent runnable + Supervisor restart loop before mixing MPP/RKNN bring-up risk.
- **Alternative**: Big-bang move all JNI into daemon in one PR (higher blast radius).

### D4 — Supervisor placement

- **Choice**: New Java type `AiDaemonSupervisor` owned from cold-start path parallel to today's `LaserApplication.initAiEngine` / `AiManager.start()`. P0 MAY still start in-process AI for compatibility until P1 cuts live JNI; Supervisor MUST be the sole owner of daemon child lifecycle.
- **Why**: Avoids forking lifecycle into multiple activities; mirrors design §5.
- **Crash policy**: Detect via `waitFor` + heartbeat timeout + optional `ping`; SIGTERM → SIGKILL; delete stale socks; exponential backoff with cap; `daemon_state=error` when capped.

### D5 — Bit0 vs stream session

- **Choice**: `laser_state` only toggles sampling gate. RTSP session start/stop remains separate cmds (`stream_detect_start` / `stop`) driven by business enable / coordinator rules (P1), same decoupling as design §6.2.
- **Suggested P1 RTSP behavior when Bit0=0**: keep RTSP/decode up, gate samples only (unless explicit stop).

### D6 — Event fan-out

- **Choice**: In P1, Java evt reader feeds existing `StreamDetectResultBus` (or thin adapter) so coordinators/SSE/overlay keep subscriber APIs. P0 may only surface `heartbeat` / `daemon_ready` / `error`.
- **Why**: Minimizes Java product churn; design requires 1:1 event type mapping.

### D7 — Build structure

- **Choice**: Add CMake target `lws_ai_daemon` that links shared static cores (`stream_detect_core`, etc.) without requiring JNI for the daemon main. Retain `libai.so` until P3 for Host tests / rollback window.
- **Why**: Reuses `ai-native-build-structure` libraries; avoids duplicating algorithm sources.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Android denies execute of unpacked binary | Prototype exec path early on emulator + RK3566; document working install location |
| Stale sock / zombie child after kill | Supervisor always unlink socks before bind/connect; pid tracking + SIGKILL timeout |
| evt write blocks decode thread | Bounded queue; drop oldest non-critical; never block detect hot path waiting on Java |
| Mid-migration dual path confusion | Short branch-only switch allowed; no product settings flag; P1 exit = no live `nativeStartStreamDetect` |
| Restart loses session | On respawn, re-push laser + ai_assist_config + last session configure/start (P1) |

## Migration Plan

1. **P0**: Daemon skeleton + Makefile/APK packaging + Supervisor spawn/restart + heartbeat. Exit: cold start shows process; kill child → backoff restart + status re-push.
2. **P1**: Wire StreamDetect + configure/start/stop + laser/assist gates + result evt → bus; disable live JNI path.
3. **P2**: Offline / process-video / manual zero-point cmds.
4. **P3**: Remove product `System.load(libai)` algorithm JNI; keep static libs for host tools if needed.

Rollback: retain `libai.so` until P3; revert Supervisor wiring and stop shipping daemon binary if P0 unstable.

## Open Questions

1. Exact APK packaging path that reliably executes on production SELinux profiles (confirm during P0 on device).
2. Heartbeat interval and Supervisor timeout numbers (design leaves implementation-tunable; suggest 1–2 s heartbeat, 5 s miss threshold—finalize in code comments / constants).
3. Whether P0 cold-start still initializes in-process `AiManager` fully, or only Supervisor + deferred JNI until P1 — default: keep existing `AiManager.start()` until P1 cutover to avoid product gap.
