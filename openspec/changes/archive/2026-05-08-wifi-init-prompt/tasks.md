## 1. Persistence and connectivity semantics

- [x] 1.1 Add a small helper or extend existing prefs (e.g. near `AppRuntimeEnvironment`) to read/write `wifi_initialization_completed` with default false when missing
- [x] 1.2 Fix and document one connectivity API for gating (`WifiStatusUtils.isWifiConnected` vs `NetworkStatusUtil.isWifiAvailable`) and use it consistently for dialog visibility and completion detection

## 2. First-connection detection

- [x] 2.1 On host screen load / onboarding entry: if flag is false and device **already** on WiFi, **immediately** persist `wifi_initialization_completed` true (same pass as connectivity check; no dialog)
- [x] 2.2 Register a `ConnectivityManager.NetworkCallback` or reuse `SimpleWifiConnectReceiver` patterns to detect transition to WiFi connected while flag is false, then persist true on the main thread (covers user who connects after seeing dialog)

## 3. Dialog and WiFi settings

- [x] 3.1 Add string resources for title/body/confirm (and optional cancel if product wants dismiss without completing)
- [x] 3.2 Implement non-leaking dialog; confirm starts `Settings.ACTION_WIFI_SETTINGS` (or launches `WifiActivity` if product chooses in-app path)
- [x] 3.3 Dismiss dialog safely in `onDestroy` / lifecycle; re-evaluate on `onResume` after returning from settings

## 4. Host integration

- [x] 4.1 Choose single entry Activity (e.g. `MainActivity` after user passes safety tips) and invoke the check: if on WiFi and flag false → persist true first; show dialog **only** when flag false **and** not on WiFi
- [x] 4.2 Add session-level guard if needed to avoid duplicate dialogs on rapid lifecycle events

## 5. Verification

- [x] 5.1 Manually verify: fresh install → dialog when offline → settings → connect → flag set → forget network → no dialog
- [x] 5.2 Manually verify: fresh install with WiFi already connected → no dialog, flag becomes true
