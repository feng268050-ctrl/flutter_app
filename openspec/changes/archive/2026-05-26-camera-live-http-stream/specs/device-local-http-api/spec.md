## ADDED Requirements

### Requirement: Camera live stream HTTP endpoint

The system SHALL expose **`GET /v1/camera/live`** on the same embedded local HTTP server and port as other `/v1/*` device routes. This endpoint SHALL stream the camera RTSP main profile (**`/PR0`**) over HTTP without `ApiResult` JSON.

- **Default:** Annex-B H.264 (`Content-Type: video/H264`, `X-Camera-Live-Format: h264`).
- **Optional:** `?format=ts` for MPEG-TS (`Content-Type: video/mp2t`, `X-Camera-Live-Format: ts`).

Semantics (single shared RTSP ingest, no redundant decode, error codes, coexistence with recording) are defined in capability **`device-local-http-camera-live`**.

#### Scenario: Live route on device LAN

- **WHEN** a client requests `http://<device-lan-ip>:8080/v1/camera/live`
- **THEN** the request MUST be handled by the local HTTP server component that serves `/v1/videos` and MUST NOT require the cloud Worker base URL

#### Scenario: Optional TS format

- **WHEN** a client requests `http://<device-lan-ip>:8080/v1/camera/live?format=ts`
- **THEN** the response MUST use `Content-Type: video/mp2t` and `X-Camera-Live-Format: ts`
