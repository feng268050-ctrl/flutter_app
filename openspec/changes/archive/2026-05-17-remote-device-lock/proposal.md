## Why

Operations and support need to **remotely disable** an on-site device without physical access—for example during maintenance, billing disputes, or safety holds. Today the app has no server-driven lock; operators cannot block Fast Mode or Engineer Mode from the cloud. Adding WebSocket `command.lock` / `command.unlock` with durable on-device state closes that gap and exposes lock status in the existing `command.stat_response` snapshot path.

## What Changes

- Handle inbound unified-envelope frames `command.lock` and `command.unlock` (empty `payload`) on the device WebSocket; lock applies immediately, unlock clears persisted lock only via `command.unlock`.
- **Persist** remote lock state across app and device reboots; local UI or settings MUST NOT clear it.
- On lock: show a non-dismissible (or policy-defined) dialog that the device was remotely locked; block entry into Fast Mode and Engineer Mode with an error; if either mode is active, **stop in-progress work** and navigate back to the home screen.
- On lock: show a **lock icon** immediately before the WiFi icon in the app top bar (`EquipmentStatusBar` on mode screens and `home_wifi_status_icon` on the main/home shell).
- Add boolean **`isLocked`** to the remote snapshot included in `command.stat_response` `payload.data` (and keep `device.online` payload aligned per existing snapshot parity rules).
- Restore normal mode entry and hide lock chrome after `command.unlock`.

## Capabilities

### New Capabilities

- `device-remote-lock`: Remote lock/unlock commands, durable lock state, UI indicators, mode-entry guards, in-session ejection from Fast/Engineer mode, and lock dialog behavior.

### Modified Capabilities

- `device-ws-unified-envelope`: Normative inbound `command.lock` and `command.unlock` (empty payload) under the unified envelope.
- `device-remote-snapshot`: Remote snapshot aggregate includes `isLocked` for serialization in `command.stat_response` / `device.online`.

## Impact

- **App**: `DeviceWebSocketConnectionManager` inbound dispatch; new lock state store (persistent); `DeviceStatusPut` / `DeviceRemoteSnapshot`; `HomePage.toPage` and/or activity entry guards; `QuickModeActivity`, `EngineerModeActivity` lifecycle; `EquipmentStatusBar`, main activity WiFi row; dialog/strings.
- **Backend**: Must send `command.lock` / `command.unlock`; consume `isLocked` from stat responses.
- **Docs**: `docs/network-api-reference.md` and device WebSocket migration notes (additive fields and commands).
