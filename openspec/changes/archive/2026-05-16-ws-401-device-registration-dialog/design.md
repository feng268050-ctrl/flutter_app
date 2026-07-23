## Context

`DeviceWebSocketConnectionManager` already classifies HTTP `401` and WebSocket close code `401` as `auth_invalid_sn`, transitions to `OFFLINE_AUTH_ERROR`, and disables automatic reconnect (`connectOrReconnect` returns early when state is `OFFLINE_AUTH_ERROR` with that error code). There is no user-visible explanation or recovery path beyond waiting for a process restart or manual code paths.

The product already has:

- `GlobalDialogUtil.showBindDeviceDialog` — WiFi-reminder shell, QR body, Cancel + Confirm (startup unbound-user check in `MainActivity`).
- `GlobalDialogUtil.showForcedDisconnectDialog` — pattern for posting from the connection manager via `ActivityUtils.getTopActivity()`.
- `DeviceQRCodeUtils.createDeviceIdentityQrCodeV2` — same QR as Device Information.

This change adds WS-401-specific copy and a **Reconnect** action that clears the auth latch and retries connect.

## Goals / Non-Goals

**Goals:**

- Show registration guidance immediately after WS `401` when a top activity exists.
- Use exact English product strings (resource-backed, zh localized).
- Reuse existing dialog layout/visual style and V2 QR generation.
- **Reconnect** = user-initiated `connectOrReconnect` after clearing `lastErrorCode` / auth latch.
- Dedupe: one dialog at a time per process (weak ref, same as bind-device dialog).

**Non-Goals:**

- Changing server registration APIs or QR payload format.
- Replacing the startup HTTP “unbound users” bind reminder (`bind_device_dialog_*` strings) — that flow stays separate with its own copy.
- Auto-reconnect after `401` without user action.
- Showing the dialog when no activity is available (log and skip, same as forced disconnect).

## Decisions

1. **Trigger site: `DeviceWebSocketConnectionManager`**
   - After transitioning to `OFFLINE_AUTH_ERROR` for `401`, post `showDeviceRegistrationDialog()` on `mainHandler`.
   - Mirror `showForcedDisconnectDialog`: require non-finishing top activity from `ActivityUtils.getTopActivity()`.

2. **Dialog API: extend `GlobalDialogUtil`**
   - Prefer `showDeviceRegistrationDialog(Context, OnReconnectListener)` over overloading `showBindDeviceDialog`, because confirm label is **Reconnect** (not Confirm) and confirm must invoke reconnect logic.
   - Reuse `R.layout.dialog_bind_device_prompt`; set confirm `TextView` text from `@string/ws_register_device_reconnect` (new key).
   - Title/subtitle from `@string/ws_register_device_dialog_title` and `@string/ws_register_device_dialog_message`.
   - Hold `WeakReference<Dialog>` dedupe field separate from bind-device ref to avoid cross-suppression bugs.

3. **Reconnect implementation**
   - Add package-visible or public method on connection manager, e.g. `retryConnectAfterAuthError(String reason)`, that synchronously clears `lastErrorCode` (or sets state to allow retry), then calls `connectOrReconnect("user_reconnect_after_401")`.
   - **Reconnect** button: dismiss dialog → call that method.
   - Do not arm `ForcedWsReconnectSuppression`.

4. **Strings (English defaults)**

   | Key | English |
   |-----|---------|
   | `ws_register_device_dialog_title` | Register This Device |
   | `ws_register_device_dialog_message` | This device is unrecognized, please scan the QR code with LaserCyber app to register it. |
   | `ws_register_device_reconnect` | Reconnect |

   - `cancel_text` reused for Cancel.
   - Add Simplified Chinese in `values-zh` (product team can refine copy in implementation).

5. **QR generation off main thread (optional)**
   - V2 bitmap generation is light; acceptable on main thread for parity with `MainActivity` bind check. If jank is observed, generate on executor then post—non-blocking for v1.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| No top activity at `401` (background) | Skip dialog + log; user sees dialog on next `401` when UI returns, or after Reconnect from settings if added later |
| Dialog while another global dialog is open | Weak-ref dedupe; only one registration dialog; does not block transport state |
| User taps Reconnect before registering on phone | Expected: retry may `401` again; same dialog re-shown (dedupe allows re-show after dismiss) |
| Confusion with startup “Bind This Device” dialog | Different string keys and trigger; document in code comment |

## Migration Plan

- Ship in app release only; no server coordination.
- Rollback: revert UI hook; transport `401` handling unchanged.

## Open Questions

- None blocking; zh translations can follow English keys during implementation.
