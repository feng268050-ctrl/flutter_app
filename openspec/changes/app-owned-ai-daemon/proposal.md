## Why

P3.3 needs the welding AI stack (`libai` / `lws_ai_daemon` + RKNN) on Linux without baking a product-only daemon into the shared rootfs. MediaMTX already established App-owned child processes via `cyber_pm`; AI must follow the same lifecycle so algorithm crashes do not take down the HMI and storage stays product-scoped under `/opt/hmi`.

## What Changes

- Vendor lws-ui `native/lensinspector` into **`native/lws_ai`** and enable Linux aarch64 build of `lws_ai_daemon` (plus linked libs).
- Add **`make build-opencv`** → `prebuilt/opencv/linux-arm64/` and **`make build-ai`** → `prebuilt/ai/linux-arm64/`.
- Ship the daemon under **`/opt/hmi/bin/lws_ai_daemon`** (libs under `/opt/hmi/lib`) via `make build-app`.
- Add a minimal Dart **`AiDaemonSupervisor`** using `cyber_pm` + Unix sockets under `/run/hmi/ai/` for cold-start smoke (`daemon_ready` / `ping`).
- Document rebuild and board smoke; **do not** add systemd units or rootfs AI binaries.

## Capabilities

### New Capabilities

- `native-lws-ai`: Source tree under `native/lws_ai`, CMake Linux daemon target, `make build-ai` / prebuilt stamp.
- `app-owned-ai-daemon`: `/opt/hmi` packaging, `cyber_pm` lifecycle, smoke spawn, no rootfs unit.
- `ai-daemon-unix-socket-ipc`: cmd/evt under `/run/hmi/ai/`, `daemon_ready` + `ping`/`pong` (Linux slice; full cmd surface deferred to P4).

### Modified Capabilities

- (none — AI was never a rootfs boot unit; MediaMTX / systemd specs unchanged)

## Impact

- New: `native/lws_ai/`, `scripts/build-opencv.sh`, `scripts/build-ai.sh`, Makefile targets, `prebuilt/opencv` + `prebuilt/ai`.
- Bundle: `scripts/hmi-bundle-common.sh` install path for AI daemon.
- App: `app/lws_hmi/lib/features/ai/` supervisor + socket client; depends on existing `cyber_pm`.
- Docs: `docs/flutter-linux-hmi-plan.md`, README, AGENTS rebuild rows.
- Out of scope: P4 AI Vision UI, full laser/AI-assist cmd sync, Android APK AI path, systemd AI unit.
