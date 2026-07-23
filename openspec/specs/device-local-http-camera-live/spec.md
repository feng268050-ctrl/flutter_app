## Purpose

Define **`GET /v1/camera/live`** on the embedded LAN HTTP server: bridge the industrial camera **RTSP main stream (`/PR0`)** to HTTP clients without redundant decode, with **Annex-B H.264** as the default format and optional **MPEG-TS**.
## Requirements
### Requirement: LAN camera preview uses MediaMTX RTSP relay

The system SHALL NOT expose **`GET /v1/camera/live`**. LAN clients SHALL obtain the camera main stream (`/PR0`) via the device-hosted RTSP relay documented in **`mediamtx-runtime-lifecycle`** at **`rtsp://<device-lan-ip>:8554/camera/pr0`**.

#### Scenario: Client seeks live preview on LAN

- **WHEN** a client needs live camera main-stream video on the device LAN
- **THEN** the client MUST use the MediaMTX RTSP relay URL and MUST NOT use any HTTP live endpoint on the local HTTP port (5580; 8080 deprecated)

