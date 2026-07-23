## Why

Today the full AI stack (`libai.so` / JNI) runs inside the App process, so algorithm or codec crashes take down the HMI, and restarting AI means killing the whole app. Product needs the C++ AI logic consolidated into an independent daemon that can be spawned, supervised, and recovered without dragging down UI.

## What Changes

- Introduce standalone native binary `lws_ai_daemon` that hosts today's `libai` algorithm/session logic as a long-lived process.
- Define dual Unix Domain Socket IPC (`cmd.sock` request/response, `evt.sock` publish) with JSON Lines protocol (v1).
- Add Java `AiDaemonSupervisor` to spawn/restart the daemon on cold start, push laser Bit0 + AI assist toggles, subscribe to events, and clean up on app exit.
- **BREAKING** (target state, phased): product path stops loading process-in `libai.so` + JNI algorithm entry points; live StreamDetect and later offline/infer move behind socket cmds/evts.
- MediaMTX / Modbus remain on Java; daemon only consumes trusted RTSP URLs and Bit0 / settings pushed from Java.

Phased delivery (aligned with `docs/ai-cpp-daemon-unix-socket-design.md`):

| Phase | Outcome |
|-------|---------|
| **P0** | Daemon skeleton + cmd/evt + heartbeat; Supervisor spawn/restart; cold-start resident process |
| **P1** | Live StreamDetect over socket; stop live-path JNI |
| **P2** | Offline / process-video / manual zero-point cmds |
| **P3** | Remove product-path JNI / in-process `libai` load |

This change implements through **P0** as the exit criterion for “C++ 收拢能够独立运行”, and specifies contracts for P1–P3 so later apply work can continue without re-proposing architecture.

## Capabilities

### New Capabilities

- `ai-cpp-daemon`: Standalone `lws_ai_daemon` process — packaging, argv/workdir, ready/heartbeat lifecycle, and hosting of AI logic outside the App process.
- `ai-daemon-unix-socket-ipc`: AF_UNIX JSON Lines protocol for `cmd.sock` / `evt.sock` (types, ack/error, laser_state, ai_assist_config, stream detect, heartbeat/events).
- `ai-daemon-supervisor`: Java supervision — spawn/restart with backoff, socket connect/subscribe, state re-push after restart, app-exit cleanup, and result fan-out into existing bus/alert paths.

### Modified Capabilities

- `native-stream-detect-pipeline`: Live pipeline control moves from JNI (`nativeStartStreamDetect` / configure / laser) to daemon cmds + evt publish (P1).
- `production-ai-inference-stream-lifecycle`: Cold-start / stop lifecycle wraps daemon Supervisor instead of (or ahead of) in-process `AiManager.start()` algorithm load (P0+).
- `stream-detect-result-bus`: Result ingress gains evt-subscription path equivalent to today's JNI callback JSON (P1).
- `ai-native-build-structure`: Native build produces and packages `lws_ai_daemon` (and runtime `.so` deps) for APK distribution.

## Impact

- **Native**: `native/lensinspector` (or adjacent) gains daemon main + socket servers; StreamDetect / OpenCV / RKNN remain logic, no longer only JNI-exported.
- **Java**: New Supervisor near `AiManager` / `LaserApplication.initAiEngine`; Modbus `DeviceStatus.isLaserOn()` Bit0 and `AiAssistanceSettings` push via cmd; subscribers replace live JNI callbacks over time.
- **Packaging / SELinux**: Executable bit under app private/`jniLibs` must be validated on RK3566; sock dir `{files}/ai_daemon/`.
- **Out of scope**: Modbus in C++; MediaMTX inside daemon; long-lived JNI+daemon dual-run product flag.
- **Source of truth for architecture**: `docs/ai-cpp-daemon-unix-socket-design.md`.
