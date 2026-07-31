## 1. Process-video AI session

- [x] 1.1 Add frame sampler (ffmpeg JPEG at media time) and JPEG size helper
- [x] 1.2 Add timeline + disk persistence + cache/paths helpers
- [x] 1.3 Extend AiInferenceSseHub with media-timeline mode / publishRunningAt
- [x] 1.4 Add AiDaemonSupervisor.offlineInferOpencvStainJpg + mapper from summary_json
- [x] 1.5 Implement ProcessVideoAiSession + Registry (UI/HTTP holders, 500 ms grid, 1× clock)
- [x] 1.6 Wire GET /v1/videos/:id/ai SSE and /ai/replay in DeviceLocalHttpServer
- [x] 1.7 Unit tests: sampleMs grid, hub media timestamps, session acquire/release

## 2. AI Vision UI + dual holder

- [x] 2.1 Add AiVisionLiveStreamDetectCoordinator with weld arbitration
- [x] 2.2 Implement AiVisionTab: PR0 preview, overlay, choose/Detect/Replay, info panel
- [x] 2.3 MonitorPage initialTabIndex + Home navigates to AI Vision tab
- [x] 2.4 flutter analyze + relevant tests

## 3. Specs / ship

- [x] 3.1 Sync delta specs into openspec/specs/**
- [x] 3.2 Mark tasks complete; archive change after verify
- [x] 3.3 Document rebuild: make build-app / make push-app
