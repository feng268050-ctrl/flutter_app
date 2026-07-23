# Java live detect path baseline (Phase 0)

Enable on RK3566 before enabling C++ pipeline:

1. Set `CameraConfig.isLiveDetectPathProfilingEnabled()` to `true` (temporary debug toggle).
2. Run weld scenario: laser ON, no native pipeline flag.
3. Capture logcat:

```bash
adb logcat -s LiveDetectPathProfiler EasyPlayerClientManger LaserDetectSampling
```

## Metrics to record

| Metric | Log prefix | Description |
|--------|------------|-------------|
| Frame accept | `frame_accept` | PR1 decode callback → holder |
| Queue delay | `detect_start queueMs` | Accept → detect worker start |
| Detect duration | `detect_done detectMs` | OpenCV JNI round-trip |
| End-to-end | sum of above | Per sampled frame |

## Comparison (post Phase 1)

Repeat with `CameraConfig.isNativeStreamDetectPipelineEnabled() == true` and tag `StreamDetect` native logs for decode/sample ms.

Store results in field test notes alongside CPU/thermal readings.
