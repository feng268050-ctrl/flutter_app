# Offline MP4 / process video regression (NV12)

After **offline-inference-nv12-unification**, process video Detect uses:

```
MediaMetadataRetriever → Bitmap → Nv12FrameUtil.fromBitmap
  → AiManager.opencvStainDetectFromNv12 → nativeOpencvStainDetectFromNv12
  → stream_detect::nv12ToBgr → fixed ROI stain pipeline
```

## Checklist

- [ ] AI Vision → local process video → **Detect** playback smooth (ExoPlayer not blocked)
- [ ] Logcat: `opencvStainDetectFromNv12` / `process_video sample_ok` at **200 ms** grid (`AI_VISION_PROCESS_VIDEO`)
- [ ] Timeline `lensDet` rows populate; session-end temporal reducer unchanged
- [ ] Emulator with `ENABLE_LENS_DET_APP=true`: no `ENGINE_NOT_RUNNING` on session create
- [ ] Compare one fixture frame: I420 vs NV12 path boxes/code should match (same bitmap source; BT.601 Java convert)

## Out of scope (this change)

- RKNN `inferFromI420` / LensGuard offline timeline
- Live `StreamDetectPipeline` (already NV12)

## Prior baseline (I420)

Archived under `openspec/changes/archive/2026-07-06-native-stream-detect-pipeline/notes/offline-mp4-regression.md`.
