## 1. P0 — Daemon skeleton & IPC

- [x] 1.1 Add CMake executable target `lws_ai_daemon` with `main` entry under `native/lensinspector` (or agreed AI native root); keep `libai.so` building in parallel
- [x] 1.2 Implement AF_UNIX `SOCK_STREAM` servers for `cmd.sock` and `evt.sock` with JSON Lines framing (`v`, `type`, `id`, `ts_ms`)
- [x] 1.3 Implement cmd handlers: `ping`, `laser_state`, `ai_assist_config`, `shutdown` (store last gate/config state; ack/error envelopes)
- [x] 1.4 Implement evt publish: `daemon_ready`, periodic `heartbeat`, daemon-level `error`/`health`; bounded write buffer / non-blocking policy
- [x] 1.5 Wire argv/env for workdir (`lens_guard`), sock dir (`ai_daemon`), and optional config path; unlink stale socks on start
- [x] 1.6 Package `lws_ai_daemon` into APK install path used for spawn; document/fix execute bit on emulator and RK3566

## 2. P0 — Java Supervisor

- [x] 2.1 Add `AiDaemonSupervisor` to spawn daemon via `ProcessBuilder`, manage pid, connect cmd + subscribe evt
- [x] 2.2 Hook Supervisor into cold-start path aligned with `LaserApplication.initAiEngine`; log `startup_phase=ai_daemon, outcome=ok|failed`
- [x] 2.3 Push initial + edge-triggered `laser_state` from `DeviceStatus.isLaserOn()` (Bit0) and full `ai_assist_config` from `AiAssistanceSettings` after every reconnect
- [x] 2.4 Implement crash/exit detection (`waitFor` + heartbeat/`ping` timeout), SIGTERM→SIGKILL, sock cleanup, exponential backoff restart with cap and `daemon_state=error`
- [x] 2.5 Stop daemon and clean socks on App terminate / AI engine stop path (alongside `AiManager.stop()`)
- [x] 2.6 Verify P0 exit: cold start shows resident daemon; kill child → restart within backoff and re-push laser + assist config

## 3. P1 — Live StreamDetect over socket

- [x] 3.1 Link StreamDetect / MPP cores into `lws_ai_daemon`; implement `configure_session`, `stream_detect_start`, `stream_detect_stop` per protocol v1
- [x] 3.2 Apply `laser_state` + `ai_assist_config` gates to sampling state machine (Idle / Streaming / Sampling); keep Bit0 decoupled from enable-holder start/stop
- [x] 3.3 Publish `session_*`, `pipeline_state`, `detect_result`, `combined_frame` on evt with payloads compatible with today's bus
- [x] 3.4 Add Java evt→`StreamDetectResultBus` adapter; route live coordinators through bus without per-subscriber JNI
- [x] 3.5 Switch `NativeStreamDetectCoordinator` (and production laser lifecycle) to Supervisor cmds; remove live-path `nativeStartStreamDetect` / setLaser JNI usage
- [x] 3.6 Verify P1 exit: Bit0 drives sampling; `detect_result` reaches Java; no process-in live StreamDetect JNI on product path

## 4. P2 — Offline / other algorithm cmds

- [x] 4.1 Define and implement `offline_infer_*` (and related) cmd types for process-video / NV12 one-frame / manual zero-point flows still on JNI
- [x] 4.2 Migrate Java callers from `AiManager` JNI algorithm entry points to Supervisor cmd + evt/response
- [x] 4.3 Verify P2 exit: product algorithm path has no remaining `AiManager` JNI detect/infer calls for those flows

## 5. P3 — Remove product in-process libai load

- [x] 5.1 Remove product-path `System.load(libai.so)` / JNI algorithm exports from App runtime (retain host/tests/static libs as needed)
- [x] 5.2 Clean makefile/packaging so APK ships daemon + required runtime `.so` only for device AI
- [x] 5.3 Verify P3 exit: App runs AI solely via daemon spawn + sockets; Host tooling still builds if required

## 6. Docs & observability

- [x] 6.1 Keep `docs/ai-cpp-daemon-unix-socket-design.md` as architecture source; note any argv/path packaging decisions discovered on device
- [x] 6.2 Align C++/Java log tags (`AiDaemon`, `StreamDetect`, `startup_phase=ai_daemon`) for cross-process correlation
