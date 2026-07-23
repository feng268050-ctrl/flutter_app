## Why

When the device WebSocket handshake is rejected with HTTP `401`, the server indicates the device serial number is not registered. Today the connection manager classifies this as `OFFLINE_AUTH_ERROR` and stops automatic reconnect, but operators receive no on-device guidance on how to register. They need a clear, actionable prompt with the same device identity QR code used elsewhere so they can scan it in the LaserCyber mobile app.

## What Changes

- On WebSocket handshake failure with HTTP `401` (and equivalent close-code `401` classification already in the transport layer), show a modal registration dialog on the main thread when a foreground activity is available.
- Dialog copy (English product strings, localized via resources): title **Register This Device**; body **This device is unrecognized, please scan the QR code with LaserCyber app to register it.**; main content is the device identity QR (V2 payload, same as Settings → Device Information / startup bind reminder).
- Actions: **Cancel** dismisses the dialog only; **Reconnect** dismisses and triggers a fresh `/ws/device` connect attempt (clears the auth-error latch so retry is allowed).
- Suppress duplicate dialogs while one is visible; do not stack multiple registration prompts for repeated `401` events in the same session.
- Keep existing behavior: no exponential-backoff automatic reconnect while in `OFFLINE_AUTH_ERROR` / `auth_invalid_sn` until the user chooses Reconnect.

## Capabilities

### New Capabilities

_(none)_

### Modified Capabilities

- `device-websocket-connectivity`: Extend auth-failure (`401`) handling with normative UI copy, QR content, button labels, reconnect semantics, and deduplication—replacing the vague “emit actionable diagnostics before retry” requirement with concrete operator-facing behavior.

## Impact

- **App**: `DeviceWebSocketConnectionManager` (post-401 UI hook, Reconnect path), `GlobalDialogUtil` (new or adapted dialog API with Reconnect callback), string resources (`values` / `values-en` / `values-zh`), optional layout tweak for confirm button label.
- **Reuse**: `DeviceQRCodeUtils.createDeviceIdentityQrCodeV2`, `dialog_bind_device_prompt` visual shell (WiFi-reminder style).
- **Tests**: Unit tests for `401` classification (existing); add or extend tests for reconnect-after-401 and dialog dedupe if testable without Espresso.
- **Backend**: No API change; registration still happens via mobile app scan.
