## Why

P2 Demo is still the app home, so operators never see a product-shaped Home or Settings surface. We need an lws-ui-aligned Home (backdrop + animated heroes + Settings entry) and a real Settings shell now, before CyberUI lands, so HAL-backed platform controls leave Demo and live behind a proper product route.

## What Changes

- Replace the startup home with a **product Home** that replicates lws-ui’s backdrop, dual animated WebP heroes, and **Settings** entry only (Quick Mode / Engineer / Monitor / AI Vision / stat cards / status chrome deferred).
- Add a **Settings** experience aligned with lws-ui’s four-tab shell (Device Information, Common Settings, Advanced Settings, Custom Home Page), implemented with **Material** stand-ins for FrostUI until CyberUI migrates.
- **Add Bluetooth** under Common → Network (lws-ui gap; reuse existing `BluetoothController` / BlueZ path).
- Move Demo’s settings-overlapping sections (Wi‑Fi, Ethernet, HTTP proxy, Bluetooth, Date & Time, mouse, keyboard, backlight, volume/speaker) into Settings; keep Demo reachable on a **hidden named route** for HAL smoke (device info / alarms / LED / debug), not as the launcher home.
- Introduce Flutter **DDD-style feature modules** (domain / application / presentation) and declarative routing — not a line-by-line Android/Kotlin port.
- Bundle Home background and animated WebP assets from lws-ui (or equivalents) into `app/hmi` assets.

## Capabilities

### New Capabilities

- `product-home-ui`: Startup Home with static backdrop, dual animated WebP overlays, and Settings navigation entry; other lws-ui home chrome deferred.
- `settings-ui`: Product Settings shell (four tabs) with Common platform groups (Network including Bluetooth, Display & Sound, Date & Time, Misc) wired to existing HAL controllers; Device Information / Advanced / Custom Home present as product structure (stubs or partial where domain data is not yet migrated).
- `hmi-app-navigation`: Named routes and initial route policy — Home is default; Settings and hidden Demo are reachable by route without Demo being the launcher.

### Modified Capabilities

- `flutter-hello-world-app`: Startup home SHALL be product Home, not P2 Demo; first-frame still must not block on heavy I/O.
- `p2-device-demo-ui`: Demo is no longer the home screen; Settings-overlapping sections are removed from Demo; Demo remains available on a hidden route for device/alarm/LED/(debug) smoke.

## Impact

- `app/hmi/lib/` — new feature modules (`home`, `settings`, shared navigation), asset wiring, `main.dart` bootstrap; Demo trimmed and demoted from `home:`.
- Assets — Home WebP/mipmap equivalents under `app/hmi/assets/`; `pubspec.yaml` asset entries.
- Reuse — existing `cyber_hal` controllers and `ui/wifi/*` widgets; no CyberUI / FrostUI package yet (Material substitutes).
- Specs — new product UI specs; update hello-world home and Demo inventory requirements.
- Out of scope — CyberUI migration, full Home chrome (Monitor / Quick / Engineer / AI / stats), welding Advanced persistence beyond stubs, Android APK path.
