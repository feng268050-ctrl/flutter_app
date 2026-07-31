# StreamDetectPipeline — Native API

C++ **`StreamDetectPipeline`** pulls MediaMTX relay PR1 independently, decodes with **Rockchip MPP** (H.264/H.265 → **NV12**), converts to BGR/RGB in-process, runs OpenCV / zero_point / edgedrawing / optional RKNN, and publishes lightweight events to Java via a **single JNI uplink callback**.

**Decode boundary:** C++ detection MUST NOT use Android `NdkMediaCodec` / Java `MediaCodec` as the long-term decode backend. Java playback (`EasyPlayerClient` + Android MediaCodec) is a **separate** RTSP session for UI only. **I420 is abandoned**; YUV contract is **NV12** only. See [`docs/MPP.md`](../../../docs/MPP.md).

> **Transition:** Some branches may still link `MediaCodecDecoder` temporarily; architecture and docs target **MPP → NV12**.

**Related**

- Architecture: [`docs/MPP.md`](../../../docs/MPP.md), [`docs/Native Stream Detection Pipeline.md`](../../../docs/Native Stream Detection Pipeline.md)
- Java bus: `StreamDetectResultBus`, `NativeStreamDetectCoordinator`
- App integration: [`docs/OPENCV_DETECT_APP_INTEGRATION.md`](../../../docs/OPENCV_DETECT_APP_INTEGRATION.md) §9

---

## JNI control surface (`NativeBridge`)

| Method | Purpose |
|--------|---------|
| `nativeStartStreamDetect(String rtspUrl)` | Open RTSP reader + decode worker |
| `nativeStopStreamDetect()` | Stop pipeline, release codec / demux |
| `nativeIsStreamDetectRunning()` | Running probe |
| `nativeSetStreamDetectLaserOn(boolean)` | Gate detect sampling (weld path) |
| `nativeSetStreamDetectBurstMode(boolean)` | 100 ms burst after native `code=-5` |
| `nativeConfigureStreamDetect(...)` | Session handles, interval ms, `sessionSource` (`live_stain_detect` / `ai_vision_live`) |
| `nativeSetStreamDetectZeroPointTargetMode(int)` | Machine-model zero-point routing |
| `nativeSetStreamDetectListener(StreamDetectNativeCallback)` | **Single** uplink for all event types |

Configure **before** start. Listener may be set once at process init (`StreamDetectNativeCallback` → `StreamDetectResultBus`).

---

## Uplink event types

Forwarded as `StreamDetectEvent.*` on the Java bus:

| Type | Fields (representative) |
|------|-------------------------|
| `detect_result` | `module`, `frameId`, `timestampMs`, `imageWidth`, `imageHeight`, `summaryJson` |
| `pipeline_state` | `state` (`running` / `idle` / `error`), `detail` |
| `session_start` | `source`, `samplingIntervalMs` |
| `session_stop` | `reason` |

Detection JSON follows existing OpenCV module contracts (`OPENCV_STAIN_DETECT_NATIVE_API.md`, `ZERO_POINT_NATIVE_API.md`).

---

## Session holders (Java)

| Holder | When | RTSP |
|--------|------|------|
| `weld` | Quick / Engineer, laser ON, `isNativeWeldStreamDetectEnabled()` | `CameraConfig.LIVE_INFERENCE_RTSP_URL` |
| `ai_vision` | AI Vision live, `isNativeAiVisionStreamDetectEnabled()` | Same relay PR1, **independent** session from `EasyPlayerClient` |

Neither holder passes image buffers to Java.

---

## Sampling

- Normal: **500 ms** (`LIVE_WELD`, `AI_VISION_LIVE`)
- Burst: **100 ms** after native `code=-5` until dual `code=0` restore (C++ scheduler; Java may call `nativeSetStreamDetectBurstMode`)

Decode may run at full FPS; only gated samples invoke detect modules.

---

## Feature flags (`CameraConfig`)

| Flag | Default | Notes |
|------|---------|-------|
| `isNativeWeldStreamDetectEnabled()` | `false` | Weld-only C++ path |
| `isNativeAiVisionStreamDetectEnabled()` | `false` | Dual-link AI Vision detect |
| `isNativeStreamDetectPipelineEnabled()` | OR of above | Bus / HTTP publisher gate |

Flags remain for **AI Vision dual-link** only (`isNativeAiVisionStreamDetectEnabled`). Weld path is always native after Phase 4.

## RTSP reconnect backoff (Phase 4)

| Constant | Value |
|----------|-------|
| `kReconnectBackoffInitialMs` | 250 |
| `kReconnectBackoffMaxMs` | 5000 |

Exponential backoff on demux read failure (30 consecutive failures trigger reconnect attempt). Tune on RK3566 field test if needed.

---

## Build & verify

```bash
make ai
bash native/lensinspector/scripts/verify_libai_jni.sh app/src/main/jniLibs/arm64-v8a/libai.so
make sync   # JNI or Java coordinator changes
```

**Logcat (native perf):**

```bash
adb logcat -v time -s StreamDetect:I StreamDetectOverlay:I NativeStreamDetect:I
```

Expect `sampled frame_id=… decode_ms=… detect_ms=… e2e_ms=…` on gated samples.

**Acceptance:** [`openspec/changes/native-stream-detect-pipeline/notes/stream-detect-pipeline-acceptance.md`](../../../openspec/changes/native-stream-detect-pipeline/notes/stream-detect-pipeline-acceptance.md)
