## MODIFIED Requirements

### Requirement: Video bytes are not on SSE routes

SSE `/ai` endpoints SHALL NOT include H.264, MPEG-TS, or MP4 bytes in the response body. Clients needing live camera main-stream video SHALL use the MediaMTX RTSP relay **`rtsp://<device-lan-ip>:8554/camera/pr0`** (capability **`mediamtx-runtime-lifecycle`**) or **`GET /v1/videos/:video_id/stream`** for recorded process video.

#### Scenario: Client expects video on ai route

- **WHEN** a client requests `GET /v1/camera/ai`
- **THEN** the response MUST NOT use `Content-Type: video/H264` or `video/mp2t`
