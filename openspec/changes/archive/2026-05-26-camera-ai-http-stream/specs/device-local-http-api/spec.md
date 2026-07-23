## ADDED Requirements

### Requirement: Camera AI stream HTTP endpoint

The system SHALL expose **`GET /v1/camera/ai`** on the same embedded local HTTP server and port as other `/v1/*` device routes. This endpoint SHALL stream the camera RTSP sub profile (**`/PR1`**) over HTTP without `ApiResult` JSON, with optional AI-composited overlay when inference is active.

- **Default:** Annex-B H.264 (`Content-Type: video/H264`, `X-Camera-Ai-Format: h264`).
- **Optional:** `?format=ts` for MPEG-TS (`Content-Type: video/mp2t`, `X-Camera-Ai-Format: ts`).
- **Mode:** `X-Camera-Ai-Mode` (`pass_through` | `composited`) indicates relay source.

Semantics (pass-through vs composited hot switch, single shared ingest, error codes, coexistence with PR1 inference / AI Vision) are defined in capability **`device-local-http-camera-ai`**.

#### Scenario: AI route on device LAN

- **WHEN** a client requests `http://<device-lan-ip>:8080/v1/camera/ai`
- **THEN** the request MUST be handled by the local HTTP server component that serves `/v1/videos` and MUST NOT require the cloud Worker base URL

#### Scenario: Optional TS format for AI stream

- **WHEN** a client requests `http://<device-lan-ip>:8080/v1/camera/ai?format=ts`
- **THEN** the response MUST use `Content-Type: video/mp2t` and `X-Camera-Ai-Format: ts`
