## 1. Spec alignment (this change)

- [x] 1.1 Add delta specs for `ai-vision-recorded-video-realtime`, `ai-frame-sampling-inference`, `lens-guard-unified-inference-result`
- [x] 1.2 Update production specs under `openspec/specs/` to match implemented behavior

## 2. App implementation (pre-change)

- [x] 2.1 ExoPlayer playback during Detect; `ProcessVideoAiSession` sampling independent of player
- [x] 2.2 Overlay synced to ExoPlayer position; `AiDetectOverlayGeometry` + fit-center content rect
- [x] 2.3 Rename `InferenceOverlayGeometry` → `AiDetectOverlayGeometry`; `InferenceOverlayFrames` → `AiDetectOverlayFrames`

## 3. Archive

- [ ] 3.1 Archive change `ai-vision-recorded-detect-playback-alignment` after review
