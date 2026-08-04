## 1. OSD apply path

- [x] 1.1 Add NameOverlay JSON editor helpers (parse `VideoOverlay`, apply enable/x/y/name with Y+50 offset) with unit tests mirroring lws-ui `CameraVideoOverlayEditor`
- [x] 1.2 Add `CameraShowTimeRequest` body builder (UTC now vs zeros) with unit tests
- [x] 1.3 Implement `CameraShowOverlayApplier` (validate coords, serialize applies, PUT showtime → GET/PUT overlays → PUT saveConf) using existing Basic Auth / port 9000 patterns
- [x] 1.4 Unit-test applier success, validation failure, and HTTP failure paths with a fake `HttpClient` or injectable transport

## 2. LAN HTTP wiring

- [x] 2.1 Register `cameraShowOverlayHandler` in `cloud_local_runtime` (or App bootstrap) to call the shared applier with host + product model
- [x] 2.2 Extend `device_local_http_parity_test` (or equivalent) so wired handler returns success shape; keep unwired `show_overlay_unavailable` coverage

## 3. Camera settings UI

- [x] 3.1 Add **Change Overlay** button on `IpCameraSettingsPage` after the preview (no inline Overlay settings group)
- [x] 3.2 Implement Overlay dialog (Enable + X + Y + Apply / Cancel) via existing Cyber/Tip dialog chrome; seed from last successful apply or defaults; edits stay local until Apply
- [x] 3.3 On Apply: one OSD apply with current params; success closes dialog; failure keeps dialog open with error; guard against double-submit while in flight
- [x] 3.4 Cancel / dismiss without Apply does not call the applier
- [x] 3.5 Add l10n for Change Overlay / dialog / Apply labels (parent ARBs + `make l10n` when touching ARBs)

## 4. Verification

- [x] 4.1 Widget/unit tests: Change Overlay after preview; editing alone does not apply; Apply success closes; failure keeps open; Cancel does not apply
- [x] 4.2 `flutter analyze` / targeted tests under `app/lws_hmi/`
- [x] 4.3 On device (optional — skipped in CI): Apply Overlay then confirm OSD on preview; smoke LAN `POST /v1/camera/show-overlay`
