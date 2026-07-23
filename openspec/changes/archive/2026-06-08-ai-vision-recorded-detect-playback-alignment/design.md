## Context

LAN clients already use two channels for recorded-video detect: **`GET /v1/videos/:video_id/stream`** (MP4 bytes) and **`GET /v1/videos/:video_id/ai`** (SSE). Both attach to the same `ProcessVideoAiSession`. The App had regressed to a static cover + session virtual clock during Detect to avoid ExoPlayer conflicting with `MediaMetadataRetriever` on some emulators.

Process-video detect now uses **OpenCV** `opencvStainDetectFromI420` (gated by `tryAcceptOpencvProcessVideoInferSample`), not RKNN `LensGuardManager.inferFromI420`. Overlay types were named `InferenceOverlay*` from the earlier RKNN-unified era.

## Goals / Non-Goals

**Goals**

- Match HTTP architecture on-device: **player plays**, **session samples**, **overlay reads timeline at player position**.
- Map detection boxes when **detect frame size** ≠ **display video size** using fit-center letterboxing (`AiDetectOverlayGeometry`).
- Update OpenSpec so requirements describe OpenCV process-video detect and client overlay, not composited encode or RKNN infer.

**Non-Goals**

- Change SSE wire format or `/stream` handler.
- Reintroduce on-device composited H.264 preview or inference MP4 mux for Detect.
- Rename every `*Inference*` symbol in the codebase (e.g. `ProcessVideoAiSession`, HTTP SSE event names).

## Decisions

1. **ExoPlayer + MMRetriever in parallel** — Accept on production hardware; same file is read via FileProvider for ExoPlayer and path-based MMRetriever for sampling (mirrors HTTP client reading `/stream` while device samples internally).
2. **Overlay position source** — `ExoPlayer.getCurrentPosition()` during Detect/Replay; session clock only schedules samples and SSE `timestampMs`.
3. **Box mapping** — Timeline stores pixel boxes + `imageWidth`/`imageHeight` from the sampled bitmap; `toOverlayBoxes()` normalizes via `AiDetectOverlayGeometry`; `DetectionOverlayView` applies fit-center `videoContentRect`.
4. **Terminology** — **Detect** / **stain detect** / **OpenCV** in recorded-video specs; reserve **infer** for RKNN/LensGuard production paths.

## Risks / Trade-offs

- **Emulator file contention** — Rare decoder issues if ExoPlayer and MMRetriever stress the same file; mitigated by FileProvider URI and separated threads; revert to cover-only only if reproduced on target devices.

## Migration

- Java: `InferenceOverlayGeometry` → `AiDetectOverlayGeometry` (done in App).
- Specs: archive this change to merge deltas into `openspec/specs/`.
