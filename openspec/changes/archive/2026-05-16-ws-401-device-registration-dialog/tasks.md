## 1. Resources and dialog UI

- [x] 1.1 Add string resources `ws_register_device_dialog_title`, `ws_register_device_dialog_message`, and `ws_register_device_reconnect` in `values` / `values-en` (English per spec) and `values-zh` (Simplified Chinese).
- [x] 1.2 Add `GlobalDialogUtil.showDeviceRegistrationDialog(Context, Runnable onReconnect)` reusing `dialog_bind_device_prompt`, wiring title/message/QR/Cancel/Reconnect with dedupe via a dedicated weak reference (parallel to bind-device dialog).

## 2. WebSocket connection manager

- [x] 2.1 After `401` classification in `onFailure` and `onClosed` paths, post registration dialog display on `mainHandler` using top activity (same guard as forced disconnect).
- [x] 2.2 Implement `retryConnectAfterAuthError` (or equivalent) to clear `auth_invalid_sn` / `OFFLINE_AUTH_ERROR` latch and call `connectOrReconnect` with a user-reconnect reason.
- [x] 2.3 Wire **Reconnect** to dismiss + `retryConnectAfterAuthError`; ensure **Cancel** only dismisses.

## 3. Tests and verification

- [x] 3.1 Extend `DeviceWebSocketConnectionTest` (or add focused test) to assert reconnect-after-auth clears latch and invokes connect (mock/spy as feasible).
- [x] 3.2 Manual: unregistered SN → WS `401` → dialog copy + QR match Device Information → Cancel leaves offline → Reconnect attempts handshake → after mobile registration, Reconnect succeeds.
