# Offline MP4 Regression (Task 5.7)

Confirms process-video detect **unchanged** by `StreamDetectPipeline` work (design non-goal).

## Scope

- **In scope:** `ProcessVideoAiSession` — ExoPlayer timeline + `MediaMetadataRetriever` samples → `AiManager.opencvStainDetectFromI420` (`StainDetectSource.OFFLINE`)
- **Out of scope:** Live RTSP / `StreamDetectPipeline`

## Code baseline

| Item | Value |
|------|-------|
| Sample interval | `AiFrameSamplingInterval.AI_VISION_PROCESS_VIDEO` = **500 ms** |
| Entry | `ProcessVideoAiSession.runInferSample` |
| JNI | `NativeBridge.nativeOpencvStainDetectFromI420` via `AiManager` |
| Timeline / SSE | `ProcessVideoAiTimeline`, `CameraAiHttpPublisher` (file session, not live bus) |

Native stream detect flags **do not** alter this path.

## Emulator / device smoke

1. `make sync` (default flags OK).
2. AI Vision → select local process video → **Detect**.
3. Logcat:

```bash
adb logcat -v time -s ProcessVideoAiHttp:I AiManager:I
```

**Pass**

- `process_video sample_ok` or `sample_fail` on 500 ms grid
- Timeline / overlay updates during playback
- No `StreamDetect` / `NativeStreamDetect` logs required for this scenario

## Unit tests (no device)

```bash
./gradlew :app:testDebugUnitTest --tests "com.lasercyber.lws.ui.common.ai.video.ProcessVideoAiSampleGridTest"
```

**Pass:** BUILD SUCCESSFUL (500 ms grid math).

## Sign-off

| Check | Pass? | Notes |
|-------|-------|-------|
| Code path isolated from live bus | ✓ | |
| 500 ms sampling | ✓ | |
| Device smoke | | |

Mark **5.7** complete after device smoke sign-off.
