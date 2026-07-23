## 1. Build and bundle MediaMTX

- [x] 1.1 Add `tools/mediamtx/` with pinned upstream tag and `scripts/ci/build-mediamtx.sh` (`GOOS=android`, `GOARCH=arm64`, CGO disabled)
- [x] 1.2 Add `make mediamtx` target; copy output to `app/src/main/assets/mediamtx/arm64-v8a/` + `version.txt`
- [x] 1.3 Gitignore generated `assets/mediamtx/`; wire Gradle pre-assemble copy (same pattern as bundled firmware)
- [x] 1.4 Document license/version in build docs and CI cache strategy

## 2. Runtime coordinator

- [x] 2.1 Implement `MediaMtxBinary` (extract asset, chmod, version compare)
- [x] 2.2 Implement YAML template renderer (`RECORDING_RTSP_URL`, path `camera/pr0`, port `8554`, `sourceOnDemand`, TCP)
- [x] 2.3 Implement `MediaMtxRelayCoordinator` (ProcessBuilder start/stop, shutdown hook, exit watchdog)
- [x] 2.4 Wire coordinator from `LaserApplication` (lazy LAN policy; recording acquires relay lease)
- [x] 2.5 Add `MediaMtxRelayUrls` (`localPr0()`, `lanPr0(deviceIp)`) and relay lease API (acquire/release)
- [x] 2.6 Add structured logging (PID, conf path, exit code, stderr tail)

## 3. Route PR0 recording through MediaMTX

- [x] 3.1 `EasyPlayerClientManger.start()`: acquire relay lease, use `rtsp://127.0.0.1:8554/camera/pr0` instead of `RECORDING_RTSP_URL`
- [x] 3.2 `EasyPlayerClientManger.stop()`: release relay lease after record teardown
- [x] 3.3 Verify `CameraController` / `CameraRecordCoordinator` paths unchanged at API level; fail record if relay not ready (existing recorder-unavailable UX)
- [x] 3.4 (Recommended) `BackgroundLoopRecorder`: same relay URL to avoid second upstream when loop record runs

## 4. Remove HTTP live path (BREAKING)

- [x] 4.1 Remove `GET /v1/camera/live` route from `DeviceLocalHttpServer`
- [x] 4.2 Delete or retire `CameraLiveHttpPublisher`, ffmpeg live bridge classes, and HTTP live-only tests
- [x] 4.3 Abandon/supersede `openspec/changes/camera-live-http-ffmpeg-h264` (do not apply in parallel)
- [x] 4.4 Update `DeviceLocalHttpCameraLiveRouteTest` → RTSP relay probe or remove HTTP live assertions

## 5. OTA upgrade

- [x] 5.1 Define OTA zip layout and manifest field for `mediamtx` artifact (coordinate with backend if needed)
- [x] 5.2 Implement install/compare in OTA apply path (`mediamtx-ota-upgrade` spec)
- [x] 5.3 Defer binary swap when relay process is running; verify cold-start upgrade

## 6. Documentation and integration

- [x] 6.1 Update `docs/network-api-reference.md`: remove `/v1/camera/live`; add RTSP URL, ffplay/VLC examples
- [x] 6.2 Update `docs/camera-http-ai-vision-integration.md` pairing (RTSP + SSE)
- [x] 6.3 Document Fast/Engineer/HTTP record ingest via relay; note single upstream invariant
- [x] 6.4 Field checklist: eth0 up → `ffplay rtsp://<device-ip>:8554/camera/pr0`; record in Fast Mode while ffplay attached — one camera RTSP session

## 7. Verification

- [x] 7.1 JVM/unit tests for config render, version compare, coordinator lease/refcount (mock process)
- [x] 7.2 Instrumented test: relay serves PR0 to LAN client + loopback recorder concurrently; camera sees one upstream
- [x] 7.3 Manual regression: Fast/Engineer record, `POST /v1/camera/record`, `GET /v1/camera/ai`; logs show relay URL on `record_start`
