## Why

Operators need to turn the IP camera’s on-screen clock + machine-name OSD on/off and position it while watching the live preview on Common Settings → Camera. lws-ui already has a working apply path (`make show-camera-overlay` → `POST /v1/camera/show-overlay` → camera HTTP `showtime` / `overlays` / `saveConf`), but lws-hmi only stubs that LAN route as unavailable and the Camera settings page has no overlay controls.

## What Changes

- Add a **Change Overlay** action button on the Camera settings page **after** the live preview; tapping it opens a dialog with all overlay parameters (enable + X + Y) matching lws-ui `show-camera-overlay`.
- Dialog uses ordinary confirm UX: edit locally → tap **Apply** once to submit the full parameter set → on success close the dialog; on failure keep the dialog open with an error.
- Implement the App apply path that mirrors lws-ui `CameraShowOverlayCoordinator`: Basic-Auth camera HTTP `PUT /System/showtime`, `GET`+`PUT /Media/Video/overlays?channel=1` (NameOverlay uses Machine Model / `product.ini` model, name Y = Y+50), then `PUT /System/saveConf`.
- Wire `DeviceLocalHttpServer` `POST /v1/camera/show-overlay` to the same apply path (replace today’s `show_overlay_unavailable` when the App can reach the camera).

## Capabilities

### New Capabilities

- `camera-osd-overlay`: Apply and persist IPC clock + NameOverlay OSD via camera HTTP (lws-ui parity), shared by Settings UI and LAN `POST /v1/camera/show-overlay`.

### Modified Capabilities

- `settings-ui`: Camera settings page SHALL offer Change Overlay after the preview; dialog edits params locally and applies once on confirm.
- `device-local-http-api`: `POST /v1/camera/show-overlay` SHALL invoke the App OSD apply path when available (not permanently stubbed as unavailable).

## Impact

- App: new OSD apply helper (reuse `cameraHttpBasicAuthorization` / host from `product.ini` `camera_ip`); Camera settings UI + overlay dialog (`IpCameraSettingsPage`); wire `cameraShowOverlayHandler` in cloud/local HTTP runtime.
- Camera module HTTP on `:9000` (admin/admin) — same contract as version fetch and lws-ui.
- Specs: `settings-ui`, `device-local-http-api`; new `camera-osd-overlay`.
- Out of scope: host `make show-camera-overlay` port (optional follow-up); AI detection overlay; MediaMTX / eth0 / recording changes; HAL portable `ip_camera` API expansion; inline Overlay settings group; per-control immediate submit.
