## ADDED Requirements

### Requirement: LAN RTSP URL is publishable for remote clients

When the product MediaMTX relay is running, the system SHALL expose a stable LAN RTSP path for the primary camera stream (`rtsp://<device-lan-ip>:8554/camera/pr0` or the product’s documented equivalent) for mobile/LAN clients, in addition to localhost preview URLs used by Settings.

#### Scenario: LAN client can target device IP RTSP

- **WHEN** MediaMTX relay is running and the device has a LAN IP
- **THEN** a LAN client MAY open `rtsp://<device-lan-ip>:8554/camera/pr0` (or documented equivalent)
- **AND** Settings preview MAY continue to use localhost MediaMTX URLs

### Requirement: Optional camera HTTP proxy is deferred unless required

A Wi‑Fi-facing HTTP reverse proxy to the camera module HTTP API (lws-ui `:9000`) is OPTIONAL for the first cloud/LAN slice. If eth0 isolation still requires tablet-mediated HTTP access for mobile tooling, the product SHALL add the proxy in a follow-up task within this change; otherwise it MAY remain unimplemented without blocking `:5580` or RTSP advertise.

#### Scenario: Missing proxy does not block local HTTP health

- **WHEN** camera HTTP proxy is not enabled
- **AND** local HTTP `:5580` is running
- **THEN** `GET /lasercyber` MUST still succeed
