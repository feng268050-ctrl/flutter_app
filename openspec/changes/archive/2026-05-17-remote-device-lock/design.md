## Context

The Android app already routes inbound device WebSocket frames through `DeviceWebSocketConnectionManager.onInboundMessage`, builds remote snapshots via `DeviceStatusPut.packRemoteSnapshot`, and serializes them for `command.stat_response` and `device.online`. Top-of-screen connectivity chrome lives in `EquipmentStatusBar` (mode/monitor/settings activities) and `home_wifi_status_icon` on the main shell. Fast Mode and Engineer Mode are separate activities launched from the WebView home (`HomePage.toPage`).

There is no remote lock today. Operators need a server-initiated hold that survives reboot and blocks privileged operating modes until explicitly released.

## Goals / Non-Goals

**Goals:**

- Process `command.lock` / `command.unlock` (unified envelope, empty `payload`) on the existing WS dispatcher.
- Persist `isLocked` in app-private storage (e.g. `SharedPreferences` via a small `DeviceRemoteLockStore`) so cold start and OTA reboot keep the device locked until `command.unlock`.
- Reflect lock in UI: modal on transition to locked; lock icon before WiFi on home and `EquipmentStatusBar`; block Fast/Engineer entry with user-visible error; eject active Fast/Engineer sessions to home with work stopped safely.
- Include `isLocked` in `DeviceRemoteSnapshot` so `command.stat_response` `payload.data` and `device.online` stay aligned.

**Non-Goals:**

- Local PIN/password unlock, settings toggle, or time-based auto-unlock.
- Locking individual tabs inside monitoring/settings (only Fast Mode and Engineer Mode are gated).
- Outbound ack frames for lock/unlock unless product later requires them (commands are fire-and-forget like `command.disconnect`).

## Decisions

### 1. Single source of truth: `DeviceRemoteLockStore`

A dedicated singleton reads/writes a boolean `remote_locked` in `SharedPreferences` (same pattern as `AppRuntimeEnvironment`). All WS handlers, snapshot builders, UI observers, and mode guards query this store.

**Rationale:** Clear separation from transient `MemoryCacheManager` entries; survives process death.

**Alternative considered:** Room column on `DeviceInfo` — rejected; lock is operational policy, not device identity metadata.

### 2. Inbound handling in `DeviceWebSocketConnectionManager`

Add branches for `command.lock` and `command.unlock` after envelope validation, mirroring `command.stat_request`:

- `command.lock`: set store true on a background thread, then `mainHandler.post` for UI side effects (dialog, eject, icon refresh broadcast).
- `command.unlock`: set store false, dismiss lock dialog if showing, refresh icons, no mode auto-launch.

Empty `payload` is accepted; extra keys are ignored.

### 3. `isLocked` on remote snapshot root

Add `Boolean isLocked` to `DeviceRemoteSnapshot`; `DeviceStatusPut.packRemoteSnapshot` sets it from `DeviceRemoteLockStore`. Serialization via existing `snapshotToMap` / Gson path automatically includes the field in `payload.data` and `device.online`.

**Rationale:** Matches user requirement and keeps parity with other top-level snapshot fields (`deviceStatus`, `processParameters`).

**Alternative:** Top-level `payload.isLocked` beside `data` — rejected to avoid splitting snapshot semantics.

### 4. Mode blocking and ejection

- **Entry guard:** Central helper `DeviceRemoteLockPolicy` (or methods on the store) used from `HomePage.toPage` before starting `QuickModeActivity` / `EngineerModeActivity`, and `onCreate`/`onResume` guards on those activities as defense in depth. Blocked entry shows a toast or dialog with a dedicated string (e.g. `remote_lock_mode_blocked`).
- **Active session:** On lock, if top activity is `QuickModeActivity` or `EngineerModeActivity`, invoke existing “stop work / safe stop” hooks used for emergency or back navigation (reuse mode-specific stop APIs where present), then `ActivityUtils.finishToMain` or explicit intent to main with `CLEAR_TOP`. Same path if lock arrives while user is already in those modes.

### 5. Lock dialog

Non-cancelable `AlertDialog` (or `GlobalDialogUtil` extension) shown when lock becomes true while app is foreground; if already locked at cold start, show once when main/mode activity resumes. Dismiss only on unlock (not on back). Copy: device remotely locked (zh/en strings).

Pattern follows `showForcedDisconnectDialog` in the same manager class.

### 6. Top bar lock icon

- **`equipment_status_bar.xml`:** Add `ImageView` `remote_lock_icon` immediately before `wifi_content_icon`, visibility bound to lock state (LiveData or manual refresh from store listener).
- **`activity_main.xml`:** Add lock `ImageView` before `home_wifi_status_icon`; main activity subscribes to lock state changes.

Use existing mipmap if suitable (`wifi_lock_icon`) or add `remote_device_lock_icon` for product distinction.

### 7. Observability

Log at INFO on lock/unlock with inbound message `id`. Unit tests for envelope dispatch, snapshot JSON contains `isLocked`, and store persistence across simulated restart (Robolectric or pure JVM store test).

## Risks / Trade-offs

- **[Risk] Stopping laser/work mid-operation on lock** → Mitigation: reuse established safe-stop paths from mode exit; document that remote lock is equivalent to an operational hold.
- **[Risk] Dialog over WebView home** → Mitigation: show from top activity; defer until `ActivityUtils.getTopActivity()` is non-null (same as forced disconnect).
- **[Risk] Server sends lock while offline** → Mitigation: lock applies only when frame received; server reads `isLocked` on next stat/on connect to learn state—no queue on device.
- **[Risk] Duplicate lock dialogs** → Mitigation: singleton dialog holder or flag `lockDialogShowing`.

## Migration Plan

1. Ship app with lock handling; server can start sending `command.lock` after fleet upgrade.
2. Additive JSON field `isLocked` — old servers ignore; new servers must treat missing as false on legacy builds only during rollout.
3. Document commands in `docs/network-api-reference.md`.

## Open Questions

- Whether lock dialog should be dismissible with “OK” while remaining locked (recommend: single acknowledgment button, modes still blocked).
- Exact safe-stop API per mode (implementation task will map to existing laser-off / program-stop handlers).
