## 1. Library — encoded frame tap

- [x] 1.1 Add `EncodedVideoSink` (or equivalent) callback API on `EasyPlayerClient` invoked with H.264/H.265 `FrameInfo` on the same path as `muxer2.writeFrame`, without requiring display decode
- [x] 1.2 Unit or instrumentation smoke: virtual Surface client receives encoded callbacks when playing `CameraConfig.RECORDING_RTSP_URL` on device/emulator with camera stack

## 2. MPEG-TS mux and publisher

- [x] 2.1 Implement `MpegTsMuxer` (or reuse proven mux helper) to wrap elementary stream into TS segments for HTTP chunking
- [x] 2.2 Implement `CameraLiveHttpPublisher` with refcounted start/stop, subscriber fan-out, bounded queue/backpressure, max subscriber cap, and `CAMERA_LIVE_HTTP` logging
- [x] 2.3 Wire publisher to `EncodedVideoSink` + single `EasyPlayerClient` on `RECORDING_RTSP_URL` (TCP); ensure teardown when refcount hits zero

## 3. HTTP route

- [x] 3.1 Register `GET /v1/camera/live` in `DeviceLocalHttpServer` with chunked response: default `video/H264` (Annex-B), optional `?format=ts` → `video/mp2t`; `X-Camera-Live-Format`; `Cache-Control: no-cache`; disconnect cleanup
- [x] 3.2 Return 503 when camera network not ready, RTSP start timeout, or subscriber limit exceeded
- [x] 3.3 (Stretch) Share encoded tap with `EasyPlayerClientManger` during PR0 recording to avoid duplicate RTSP; otherwise log `duplicate_rtsp=recording_active`

## 4. Tests and docs

- [x] 4.1 Add JVM tests for TS mux boundaries / publisher refcount (where feasible without hardware)
- [x] 4.2 Add `DeviceLocalHttpProbeTest` or integration test: GET `/v1/camera/live` returns 503 when publisher cannot start (mocked) or 200 content-type when stubbed
- [x] 4.3 Document `GET /v1/camera/live` in `docs/network-api-reference.md` (default H.264, `?format=ts`, VLC/ffplay/Flutter examples, coexistence note)
- [x] 4.4 Field checklist: eth0 up → `ffplay -f h264 http://<device-ip>:8080/v1/camera/live`; optional `?format=ts`; verify one `RTSP start` log per viewer epoch; optional concurrent recording + live
