## Context

`app/hmi` today boots into `P2DemoPage` — a single Material scroll that doubles as HAL validation and ad-hoc “settings.” lws-ui’s product Home (`MainActivity` + animated WebP backdrop) and Settings (`DeviceSettingActivity` four-tab shell) are the visual/behavioral reference, but they are Android/Kotlin + FrostUI. CyberUI is not in-tree yet, so this change delivers product Home + Settings with **Material stand-ins**, Flutter idioms, and a **DDD feature layout**, wiring to existing `cyber_hal` controllers rather than porting Activities/Fragments.

## Goals / Non-Goals

**Goals:**

- Product **Home** as the launcher route: static backdrop, dual animated WebP overlays, **Settings** entry (layout/composition aligned with lws-ui; not a pixel-perfect Android port).
- Product **Settings** shell matching lws-ui’s four tabs; **Common Settings** fully usable for platform concerns, including **Bluetooth** under Network.
- **DDD-style** feature modules + declarative navigation; presentation depends on application/domain ports, not on Demo widgets.
- Demote Demo: **hidden named route**, strip sections that Settings owns; retain device/alarm/LED/(debug) smoke.
- Material widgets as temporary FrostUI substitutes (`Card`/`ListTile`/`Switch`/`Slider`/`TabBar`/`SegmentedButton`, etc.).

**Non-Goals:**

- CyberUI / FrostUI package migration or live blur pipeline.
- Full lws-ui Home chrome (clock, Wi‑Fi indicator, four stat cards, Quick/Engineer/Monitor/AI Vision entries, home prompt queue).
- Full Advanced Settings Modbus/Room persistence and Custom Home drag layout (structure + placeholders only unless data already available).
- Mouse/keyboard as product marketing features beyond operator OS controls already proven on Demo.
- Android APK / YNHAPI path.

## Decisions

### 1. Feature modules (DDD) over Demo-centric UI

**Choice:** Introduce `lib/features/{home,settings,demo}/` with `domain/`, `application/`, `presentation/` (and thin `data/` adapters where needed). Shared navigation/theme under `lib/app/`. Keep `lib/platform/` as HAL re-exports; Settings application services take abstract controllers from `BoardBindings`.

**Why:** Matches “Flutter best practice + DDD, not translation.” Demo `StatefulWidget` god-objects stay isolated; Settings use cases (toggle Wi‑Fi, set brightness, pair Bluetooth) are testable without widgets.

**Alternatives:** Keep everything under `lib/ui/` with ViewModels only — rejected (harder to grow P4 business screens). Port Fragment/ViewModel names 1:1 — rejected (Android idioms, not Dart).

### 2. Navigation: named routes, Home initial

**Choice:** Lightweight declarative routing (`GoRouter` **or** `Navigator` + `onGenerateRoute` / `routes` map — prefer `go_router` if dependency cost is acceptable; otherwise Material `routes` to avoid new deps). Routes at minimum:

| Route | Purpose | Visibility |
|-------|---------|------------|
| `/` | Product Home | Launcher |
| `/settings` | Settings shell | From Home entry |
| `/demo` | P2 Demo (trimmed) | Hidden (no Home chrome link; deep-link / debug URL / secret gesture optional later) |

**Why:** Spec needs Demo reachable but not home. Named routes survive CyberUI later.

**Alternatives:** Keep `home: P2DemoPage` with overlay Home — rejected. Full nested Navigator per tab early — deferred; Settings tabs are local `TabBar`/`DefaultTabController` first.

### 3. Home scope: backdrop + animation + Settings only

**Choice:** Port visual stack conceptually from lws-ui:

1. Full-screen static `home_back` (WebP/PNG).
2. Left/right animated WebP overlays (`home_left_400` / `home_right_400`).
3. A clear **Settings** affordance (icon/button) navigating to `/settings`.

Omit heroes (Quick/Engineer), bottom Monitor/AI, stat cards, clock/status for this change.

**Assets:** Copy from lws-ui `res/mipmap-mdpi/` into `app/hmi/assets/home/` (document source in README comment or assets note). Decode via Flutter `Image.asset` / animation package as needed for multi-frame WebP on flutter-pi.

**Why:** User-scoped MVP; avoids blocking on business Home.

### 4. Settings shell: four tabs + Bluetooth; Linux extras under Common

**Choice:** Tab order fixed (lws-ui):

0. **Device Information** — reuse existing Demo identity/version rows where data already exists (SN, versions); OTA/secret taps deferred or stubbed.
1. **Common Settings** — Network (Wi‑Fi, HTTP Proxy, **Bluetooth**, **Ethernet**), Display & Sound (brightness, volume; language/unit/screen-off/sound-effect as UI with persist where HAL/store exists, else stub), Date & Time, input (Mouse, Keyboard layout), Misc stubs (boot self-check / ground-lock) if no store yet.
2. **Advanced Settings** — group structure placeholders (not full Modbus write matrix unless already trivial).
3. **Custom Home Page** — placeholder explaining deferred until Home stats land.

**Bluetooth:** New Network row + detail page (adapter enable, discoverable/pairable, scan/pair/connect, A2DP sink) reusing `LinuxBluezBluetoothController` patterns from Demo — rewritten as Settings presentation + application service, not copy-paste of `BluetoothDemoSection`.

**Why:** User asked to replicate Settings and **add** Bluetooth. Ethernet/Mouse/Keyboard are not in current lws-ui Common Network/Display groups but **are** Settings-owned once Demo drops them; putting them in Common avoids orphaning HAL UX.

**Alternatives:** Strict lws-ui-only rows (drop Ethernet/Mouse/Keyboard from UI) — rejected (would delete proven operator controls). Fifth “Platform” tab — rejected (diverges from lws-ui shell).

### 5. Material stand-ins for FrostUI

**Choice:** Mapping table (presentation only):

| FrostUI (lws-ui) | Material stand-in |
|------------------|-------------------|
| FrostCard / groups | `Card` + `ListTile` sections |
| FrostSwitch | `SwitchListTile` |
| FrostSegmentedControl | `SegmentedButton` / `ToggleButtons` |
| FrostCapsuleSlider / volume | `Slider` + label |
| FrostButton | `FilledButton` / `TextButton` |
| Top tabs | `TabBar` + `TabBarView` |
| Frost dialogs | `showDialog` / `AlertDialog` |

Theme remains dark Material 3; no fake glass blur.

**Why:** CyberUI not ready; keeps layout hierarchy portable to `Cyber*` later.

### 6. Demo demotion

**Choice:** After Settings lands, Demo `ListView` **removes** Ethernet, Wi‑Fi, HTTP, Bluetooth, DateTime, Mouse, Keyboard, backlight, speaker/volume sections. **Keeps** device information, alarm temperatures, RGB LED, and Debug (USB/LAN SSH) for engineering smoke. Route `/demo` only.

**Why:** Avoid duplicate UIs fighting the same controllers; Debug stays off product Settings (aligns with lws-ui Dev/secret surfaces).

### 7. First-frame / persistence

**Choice:** Home paints assets first; `BoardBindings` + `restorePersistedSettings` stay post-frame (same as Demo today). Settings screens acquire controllers lazily on tab/section open.

**Why:** Preserve boot KPI from `flutter-hello-world-app`.

## Risks / Trade-offs

- **[Risk] Animated WebP on flutter-pi** → Mitigation: verify decode on device early; if broken, convert to GIF/APNG or use a maintained multi-frame decoder package; keep static frames as fallback.
- **[Risk] Settings tab stubs look “empty”** → Mitigation: clear placeholder copy for Advanced/Custom Home; Device Information shows live rows that already work.
- **[Risk] Duplicate controller lifecycle if Demo + Settings both open** → Mitigation: single app-scoped bindings/owner; Demo hidden by default; document that only one consumer should own sessions.
- **[Risk] Asset size / license from lws-ui** → Mitigation: copy only needed Home mipmaps; keep binary assets in git as today for lws-ui sibling; note provenance in change notes.
- **[Trade-off] Material ≠ Frosted Glass** → Accept until CyberUI; structure tabs/groups so swap is mostly presentation.
- **[Trade-off] Linux extras in Common** → Slightly richer than Android Settings; documented as intentional HMI delta.

## Migration Plan

1. Land navigation + empty Home/Settings shells; switch `MaterialApp` initial route to Home.
2. Add assets and Home visuals; Settings entry works.
3. Port Common Settings sections from Demo logic into feature modules; wire HAL.
4. Add Bluetooth Settings UI; strip moved sections from Demo; register `/demo`.
5. Device Information live rows; Advanced/Custom placeholders.
6. Widget/golden or smoke tests for routes + one Settings section; `flutter analyze` / existing HAL tests unchanged.

Rollback: restore `home: P2DemoPage` and re-enable Demo sections via git revert of app UI commit(s).

## Open Questions

- Prefer adding `go_router` vs zero-dep `routes` map? (Default in implementation: **zero-dep first** unless nesting pain appears.)
- Secret gesture / long-press to open `/demo` in this change, or route-only for developers? (Default: **route-only**; optional long-press can be a small follow-up.)
- Language / unit / screen-off / sound-effect: stub UI only, or persist to a new prefs store now? (Default: **stub where no HAL**; brightness/volume/time/network/BT/input fully wired.)
