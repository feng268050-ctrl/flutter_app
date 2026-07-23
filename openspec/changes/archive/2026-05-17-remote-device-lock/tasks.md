## 1. Lock state and snapshot

- [x] 1.1 Add `DeviceRemoteLockStore` (SharedPreferences) with `isLocked()`, `setLocked(boolean)`, and listener/callback for UI refresh
- [x] 1.2 Add `isLocked` field to `DeviceRemoteSnapshot`; set from store in `DeviceStatusPut.packRemoteSnapshot`
- [x] 1.3 Unit test: snapshot serialization includes `isLocked` true/false; store survives preference round-trip

## 2. WebSocket commands

- [x] 2.1 Handle inbound `command.lock` and `command.unlock` in `DeviceWebSocketConnectionManager` (empty payload, log inbound `id`)
- [x] 2.2 On lock: persist true, post UI work (dialog, eject, icon refresh); on unlock: persist false, dismiss dialog, refresh icons
- [x] 2.3 Unit test: parsed lock/unlock frames dispatch to store (mock or test doubles)

## 3. Mode guards and session ejection

- [x] 3.1 Add `DeviceRemoteLockPolicy` helpers: `checkModeEntryBlocked(Context)` and `ejectIfLockedModeActive()`
- [x] 3.2 Guard `HomePage.toPage` for Fast Mode (page 1) and Engineer Mode (page 2) with user-visible error
- [x] 3.3 Add `onResume` defense in `QuickModeActivity` and `EngineerModeActivity` to finish to home when locked
- [x] 3.4 Wire safe-stop + navigate home when lock applies during active Fast/Engineer session

## 4. UI: dialog and top-bar icon

- [x] 4.1 Add zh/en strings for remote lock dialog and mode-blocked error
- [x] 4.2 Implement remote lock dialog (non-cancelable while locked; dismiss on unlock) via `GlobalDialogUtil` or equivalent
- [x] 4.3 Add lock `ImageView` before WiFi in `equipment_status_bar.xml` and bind visibility in `EquipmentStatusBar`
- [x] 4.4 Add lock `ImageView` before `home_wifi_status_icon` in `activity_main.xml`; update main activity to observe lock store
- [x] 4.5 Show lock dialog on cold start when already locked (once per resume cycle)

## 5. Documentation and verification

- [x] 5.1 Update `docs/network-api-reference.md` with `command.lock`, `command.unlock`, and `isLocked` in stat snapshot
- [x] 5.2 Manual check: lock → dialog + icon + blocked mode entry; unlock → cleared; reboot while locked stays locked; stat_response contains `isLocked`
