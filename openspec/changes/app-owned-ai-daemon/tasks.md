## 1. OpenSpec and vendor tree

- [x] 1.1 Land proposal / design / specs for `app-owned-ai-daemon`
- [x] 1.2 Copy lws-ui `native/lensinspector` → `native/lws_ai` (exclude bulky build outs / `_cache` if present)
- [x] 1.3 Add `native/lws_ai/README.md` documenting `make build-ai` and Linux paths

## 2. CMake Linux daemon

- [x] 2.1 Enable `lws_ai_daemon` for Linux aarch64 (not Android-only)
- [x] 2.2 Drop Android-only `log` link on Linux; set `RPATH=$ORIGIN/../lib`
- [x] 2.3 Wire argv/env defaults compatible with `/run/hmi/ai` and `/var/lib/hmi/ai` when not overridden

## 3. OpenCV and AI host builds

- [x] 3.1 Add `scripts/build-opencv.sh` + `make build-opencv` → `prebuilt/opencv/linux-arm64`
- [x] 3.2 Add `scripts/build-ai.sh` + `make build-ai` → `prebuilt/ai/linux-arm64` with stamp
- [x] 3.3 Extend `check-prebuilt` / `build-runtime-deps` as appropriate; clear errors if inputs missing

## 4. Bundle and App smoke

- [x] 4.1 `hmi_bundle_install_ai` in release + debug staging (bin + lib)
- [x] 4.2 Dart `AiDaemonSupervisor` + thin socket client under `app/lws_hmi/lib/features/ai/`
- [x] 4.3 Wire Linux init (non-fatal); unit-test protocol framing where pure-Dart

## 5. Docs and verify

- [x] 5.1 Update `docs/flutter-linux-hmi-plan.md`, README Make commands, AGENTS rebuild rows
- [x] 5.2 Host gate: `prebuilt/ai/linux-arm64/lws_ai_daemon` after `make build-ai`; document board smoke after `push-app`
