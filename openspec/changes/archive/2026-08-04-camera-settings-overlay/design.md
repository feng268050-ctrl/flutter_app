## Context

lws-ui applies camera OSD via `CameraShowOverlayCoordinator`:

1. `PUT /System/showtime` — clock at `(X, Y)`; when enable=1 fills UTC now, else zeros.
2. `GET` then `PUT /Media/Video/overlays?channel=1` — mutates `VideoOverlay.NameOverlay` (`enable`, `x=X`, `y=Y+50`, `name=<Machine Model>` when on; `enable=0` when off).
3. `PUT /System/saveConf` — persist.

Host entry: `make show-camera-overlay ENABLE=0|1 [X=…] [Y=…]` → `POST /v1/camera/show-overlay` on `:5580`. Ranges: X `0…384`, Y `0…288` (when enable=1, Y max `238` so Y+50 ≤ 288). Defaults X/Y = 10.

lws-hmi already has:

- Camera settings page with Status / Type / Version + preview + demo record.
- `CameraDeviceInfoCache` (Basic Auth `admin:admin`, port 9000, case-sensitive `Authorization`).
- `DeviceLocalHttpServer` route parsing for show-overlay, but `cameraShowOverlayHandler` is null → `show_overlay_unavailable`.
- Cyber dialog chrome (`showCyberDialog` / `CyberPromptContent` / TipDialogHost) used elsewhere in Settings.

## Goals / Non-Goals

**Goals:**

- **Change Overlay** action after the live preview; dialog hosts enable + X + Y.
- Ordinary dialog UX: edit locally → **Apply** once → success closes dialog.
- Shared App apply path matching lws-ui HTTP sequence and validation.
- Wire LAN `POST /v1/camera/show-overlay` to the same apply path.
- Keep the main Camera page uncluttered (no inline Overlay settings group).

**Non-Goals:**

- Inline Overlay rows/group on the Camera page body.
- Per-control immediate submit / sibling lock while editing.
- Porting host `make show-camera-overlay` into this repo (optional later).
- Expanding portable HAL `ip_camera` with OSD APIs.
- AI detection overlay / Monitor HUD.
- Reading back current OSD from camera on page open (dialog seeds from last successful apply in memory or defaults).

## Decisions

### 1. App-owned apply helper (not HAL)

**Choice:** Add an App module (e.g. `CameraShowOverlayApplier` under `features/ip_camera/application/`) that performs the three camera HTTP calls with existing Basic Auth helpers.

**Why:** Version fetch is already App-owned HTTP; OSD is the same IPC surface. HAL stays health/streams/recording.

**Alternatives:** Put OSD on `IpCameraController` — rejected to avoid product HTTP/auth in portable HAL.

### 2. Shared apply for UI and LAN HTTP

**Choice:** One applier; dialog Apply calls it once with the full `{enable, positionx, positiony}`; `cloud_local_runtime` / local HTTP sets `cameraShowOverlayHandler` to wrap the same applier (resolve host + machine model from `ProductInfo`).

**Why:** Matches lws-ui coordinator semantics. Avoids divergent enable/X/Y rules.

### 3. Machine Model source

**Choice:** NameOverlay `name` is the Device Information **Device Model** string (`productDeviceModelDisplay(brand, model)` via `cameraOverlayDeviceName`). No dialog field to edit the name. Resolved fresh from `ProductInfo` at Apply / LAN POST time. When brand and model are both missing, submit empty name (do not burn `-` onto OSD).

**Why:** Operator asked for Device Info parity without a separate name setting.

### 4. UI: button after preview → dialog (not page group)

**Choice:** Place a **Change Overlay** button after the preview (same action band as Record, or immediately under the preview row). Tapping opens a Cyber/Tip prompt dialog whose body contains Enable + X + Y. No Overlay `SettingsGroup` on the page.

**Why:** Keeps Status/Type/Version + preview primary; parameters live in one modal.

### 5. Ordinary Apply / Cancel dialog interaction

**Choice:** Controls only mutate local dialog state. Primary **Apply** (confirm) runs one OSD apply with the current local values; on success dismiss the dialog; on failure keep it open, show a short error, re-enable Apply. Secondary **Cancel** / dismiss closes without calling the applier. While Apply is in flight, disable Apply (and preferably other dialog controls) to prevent double-submit.

**Why:** Operator asked for normal dialog semantics — batch edit, one apply, then close — not per-field immediate submit.

**Alternatives:** Immediate submit per field — rejected.

### 6. Failure UX

**Choice:** Keep dialog open on failure; transient error (in-dialog or SnackBar). LAN route returns structured `ApiResult` failure (existing server shape).

### 7. Initial values

**Choice:** Dialog seeds from last successful apply in the page session, else defaults enable off / X=10 / Y=10. No mandatory GET-overlays on open in v1.

**Why:** Camera GET is slow/fragile; Settings is write-oriented here.

## Risks / Trade-offs

- **[Risk]** Concurrent LAN POST + dialog Apply race on camera → **Mitigation:** single-threaded applier mutex shared by UI and handler.
- **[Risk]** Dart `HttpClient` auth header case issues → **Mitigation:** reuse `preserveHeaderCase: true` / wget fallback if needed for PUT.
- **[Risk]** Dialog covers preview so live OSD feedback is behind the modal → **Mitigation:** after successful Apply the dialog closes so the operator can see the preview.
- **[Risk]** enable=1 with Y>238 rejected → **Mitigation:** validate (or clamp) before apply; show error without closing.

## Migration Plan

- Ship via `make build-app` + `make push-app` (App-only). No rootfs/overlay change.
- Existing boards: LAN show-overlay starts working once App is updated; no factory reflash required.
- Rollback: previous App build restores null handler / no Change Overlay button.

## Open Questions

- None blocking; host Make helper port deferred.
