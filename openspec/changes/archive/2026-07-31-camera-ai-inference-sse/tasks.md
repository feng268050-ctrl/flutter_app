## 1. SSE framing

- [x] 1.1 Add `AiInferenceSseJson` + `AiInferenceSseHub` (idle/start/running/stop/error, 15s idle, connection-relative clock)
- [x] 1.2 Add unit tests for idle-first connect and `running` timestampMs clock

## 2. Publisher + HTTP route

- [x] 2.1 Add `CameraAiHttpPublisher` mapping lens_det `detect_result` / session / pipeline_state → hub
- [x] 2.2 Wire `DeviceLocalHttpServer._handleCameraAi` to SSE when available; keep plain 503 otherwise
- [x] 2.3 Update parity tests for unavailable + available (idle) paths

## 3. Daemon bridge + weld lifecycle

- [x] 3.1 Share `AiDaemonSupervisor` instance; keep evt subscription; add StreamDetect/laser/assist cmd helpers
- [x] 3.2 Add weld StreamDetect coordinator (laser ON → PR1 start; OFF → stop/`laser_off`)
- [x] 3.3 Wire `cameraAiAvailable` + publisher into `CloudLocalRuntime` / App startup

## 4. Docs / verify

- [x] 4.1 `flutter analyze` / targeted tests for new AI + local-http files
