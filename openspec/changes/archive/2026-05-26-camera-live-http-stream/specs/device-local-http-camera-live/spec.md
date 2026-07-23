## ADDED Requirements

### Requirement: Camera live HTTP endpoint

The system SHALL expose **`GET /v1/camera/live`** on the embedded local HTTP server (`0.0.0.0:8080`). When the request is accepted, the system SHALL bridge to the industrial camera **RTSP main stream** at `CameraConfig.RECORDING_RTSP_URL` (path **`/PR0`**, TCP transport consistent with existing `EasyPlayerClient` usage). The response SHALL be HTTP **200** with a chunked body containing the camera’s encoded video bitstream **without re-encoding** to another codec.

- **Default:** **`Content-Type: video/H264`** with **Annex-B H.264** elementary stream bytes.
- **Optional `?format=ts`:** **`Content-Type: video/mp2t`** with **MPEG-TS** muxed from the same encoded access units.
- **Optional `?format=h264`:** same as default.
- The response SHALL include **`X-Camera-Live-Format`** with value **`h264`** or **`ts`** matching the active mode.

#### Scenario: Client opens default live stream

- **WHEN** a client sends `GET /v1/camera/live` (no `format` query) while the camera network is configured and RTSP is reachable
- **THEN** the response status MUST be 200, `Content-Type` MUST be `video/H264`, `X-Camera-Live-Format` MUST be `h264`, and the body MUST deliver continuous Annex-B H.264 access units while the connection remains open

#### Scenario: Client requests MPEG-TS

- **WHEN** a client sends `GET /v1/camera/live?format=ts` while RTSP is reachable
- **THEN** the response status MUST be 200, `Content-Type` MUST be `video/mp2t`, `X-Camera-Live-Format` MUST be `ts`, and the body MUST deliver continuously muxed transport-stream bytes while the connection remains open

#### Scenario: Wrong method

- **WHEN** a client sends a method other than `GET` to `/v1/camera/live`
- **THEN** the server MUST NOT return a successful live stream body

### Requirement: Single shared RTSP ingest for HTTP live

The system SHALL maintain **at most one** active RTSP ingest session to `RECORDING_RTSP_URL` dedicated to HTTP live bridging while any `GET /v1/camera/live` connection is open. Multiple simultaneous HTTP viewers requesting the **same** live format SHALL share that ingest via in-process fan-out. The system SHALL NOT open a separate RTSP session per HTTP client.

#### Scenario: Two concurrent viewers same format

- **WHEN** two clients connect to `GET /v1/camera/live` at the same time with the same effective format (both default H.264 or both `format=ts`)
- **THEN** the device MUST use one shared RTSP ingest and MUST fan out encoded data to both connections

#### Scenario: Last viewer disconnects

- **WHEN** the last active `GET /v1/camera/live` connection closes
- **THEN** the shared RTSP ingest for HTTP live MUST stop within a reasonable teardown window

### Requirement: No redundant video decode for HTTP live

For the HTTP live bridge path, the system SHALL NOT decode video to YUV/RGB solely to serve HTTP clients. Encoded access units from the RTSP demux path SHALL be relayed to HTTP subscribers (directly for H.264, or via MPEG-TS mux when `format=ts`). Display decode (`MediaCodec` to `Surface`/`TextureView`) for HTTP live MUST be disabled or bypassed when the pass-through path is active.

#### Scenario: Publisher active without display

- **WHEN** HTTP live is streaming and no UI surface requires preview for that ingest
- **THEN** the implementation MUST NOT run a full 1080p decode pipeline solely for HTTP (e.g. no per-viewer `TextureView` decode)

### Requirement: Coexistence with PR0 recording

When `EasyPlayerClientManger` is actively recording from the main stream (`RECORDING_RTSP_URL`), the system SHOULD avoid opening a second RTSP session to the same URL for HTTP live by sharing encoded frames from the recording client when technically feasible. If sharing is not implemented, HTTP live MAY use a separate RTSP session and MUST log a diagnosable warning (`duplicate_rtsp=recording_active`) when both recording and HTTP live ingest run concurrently.

#### Scenario: Recording active with live HTTP

- **WHEN** recording on PR0 is active and a client requests `GET /v1/camera/live`
- **THEN** the system MUST either serve live video from a shared encoded-frame tap on the recording client OR log that duplicate PR0 RTSP is in use

### Requirement: Live stream error responses

When the camera network is not ready, RTSP cannot be established within a bounded start timeout, or the publisher fails, the system SHALL respond with HTTP **503** and a short plain-text body (not an unbounded hang). When the maximum number of concurrent live subscribers is exceeded, the system SHALL respond with HTTP **503**.

#### Scenario: Camera unreachable

- **WHEN** `GET /v1/camera/live` is requested and RTSP to `RECORDING_RTSP_URL` cannot be established
- **THEN** the response status MUST be 503 and the connection MUST close without pretending to stream video

#### Scenario: Subscriber limit

- **WHEN** active live HTTP subscribers already equal the configured maximum and another client connects
- **THEN** the new request MUST receive HTTP 503

### Requirement: Live stream cache headers

Successful live responses SHALL include **`Cache-Control: no-cache`**. The endpoint SHALL NOT wrap the stream body in `ApiResult` JSON.

#### Scenario: Headers on success

- **WHEN** live streaming starts successfully
- **THEN** the response MUST include `Cache-Control: no-cache` and MUST NOT use the `ApiResult` envelope for the stream body
