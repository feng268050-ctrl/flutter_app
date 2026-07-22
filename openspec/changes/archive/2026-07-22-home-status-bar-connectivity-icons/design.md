## Context

Home already paints a **camera** link glyph as a lone top-right `Positioned` widget (`HomeCameraStatusIcon`). Specs still call other status-bar chrome (Wi‑Fi, recording, remote lock) optional. `AppServices` already owns live `WifiController` and `BluetoothController` streams used by Settings; Home does not subscribe to them yet.

Operators expect phone/laptop-like connectivity indicators: **hidden when the radio/adapter is off**, visible when enabled, with a distinct **connecting** affordance.

## Goals / Non-Goals

**Goals:**

- Abstract a **Home status-bar strip** (top-right) that lays out status glyphs with consistent spacing/alignment.
- Move the existing camera icon into that strip (same visual slot family as today).
- Add **Wi‑Fi** and **Bluetooth** icons with phone-like visibility and connecting/connected/idle-on styles, driven by existing HAL streams.
- Keep Home **first paint** free of blocking Wi‑Fi/BT I/O (subscribe after mount / use current snapshots only).

**Non-Goals:**

- Global (non-Home) system status bar; Monitor/Settings chrome parity.
- Tapping icons to open Wi‑Fi/BT Settings (can follow later).
- Recording / remote-lock / cellular / battery glyphs.
- New HAL APIs or D-Bus probes solely for status-bar animation.
- Moving status-bar widgets into `cyber_ui` (App-local is enough for this slice).
- Exact pixel clone of Android/iOS asset packs — icon-font composition is preferred (same as camera).

## Decisions

### 1. Abstract strip first, then add icons

**Choice:** Introduce `HomeStatusBar` (or equivalent) under `features/home/presentation/` as a right-aligned `Row` of slots; Home hosts one `Positioned` that contains the strip.

**Not:** Keep adding independent `Positioned` icons beside the camera.

**Rationale:** Camera is already in the “Wi‑Fi slot area”; Wi‑Fi/BT will share that region. A strip owns gap, hit-target size, and future slots without layout thrash in `home_page.dart`.

### 2. Icon order (right-aligned)

**Choice:** Left → right inside the strip: **Wi‑Fi · Bluetooth · Camera** (camera remains the rightmost glyph, closest to the previous lone position).

**Rationale:** Matches common phone ordering (radios then product-specific status) and minimizes visual jump for the existing camera icon.

### 3. Visibility = radio/adapter enabled

| Glyph | Hidden when | Shown when |
|-------|-------------|------------|
| Wi‑Fi | `WifiRadioState.off` | `starting`, `on`, `error` |
| Bluetooth | `BluetoothAdapterState.off` | `starting`, `on`, `error` |
| Camera | (unchanged — always present per existing Home camera requirement when IP camera is in product scope) | existing phases |

**Rationale:** Matches the product ask「未开启时不显示」and Settings’ notion of “radio on” (`on` / `starting`).

### 4. Phase mapping (UI-only; no HAL change)

**Wi‑Fi UI phases** (derived in App):

| UI phase | Source |
|----------|--------|
| `connecting` | radio `starting`, or connection `associating` / `obtainingIp` |
| `connected` | connection `connected` (optionally use `signalDbm` for bar strength) |
| `onIdle` | radio enabled, connection `disconnected` or `failed` |
| _(hidden)_ | radio `off` |

**Bluetooth UI phases** (derived in App):

| UI phase | Source |
|----------|--------|
| `connecting` | adapter `starting`, or an outstanding pairing challenge (if exposed) |
| `connected` | adapter on and **any** remote `connected == true` |
| `onIdle` | adapter on/error with no connected remotes |
| _(hidden)_ | adapter `off` |

BlueZ today has no dedicated “device connecting” enum on the controller; do **not** invent polling. Adapter `starting` + pairing challenge cover the common in-progress cases; Settings connect actions that briefly lack a stream event simply show `onIdle` until `connected` flips — acceptable for v1.

### 5. Visual language

**Choice:** Material / icon-font stacks (wifi / bluetooth / sync spinner accents), same pattern as `HomeCameraStatusIcon`. Signal strength MAY use `Icons.wifi` / `wifi_1_bar` / `wifi_2_bar` / `wifi_off`-style variants when `signalDbm` is present; otherwise a single connected wifi glyph is enough.

**Not:** New PNG asset packs from lws-ui unless icon-font proves inadequate on-device.

### 6. Data wiring

**Choice:** Strip (or small per-icon controllers) reads `AppScope` / injected `WifiController` + `BluetoothController`, seeds from `currentRadio` / `currentConnection` / `currentAdapterState` / `currentDevices`, then listens to streams. Camera continues to take `IpCameraUiStatus` from Home (or the strip accepts it as a parameter).

**Not:** Duplicate Wi‑Fi/BT sessions on Home; not polling `wpa_cli` / `bluetoothctl` from presentation code.

### 7. Spec scope

**Choice:** Delta only `product-home-ui` — add status-bar strip + Wi‑Fi/BT requirements; tighten the Settings-entry requirement text that still marks Wi‑Fi chrome as optional.

## Risks / Trade-offs

- **[Risk] Brief BT connect without a connecting stream** → Mitigation: document v1 mapping; revisit only if operators find it confusing.
- **[Risk] `error` radio/adapter still shows an icon** → Mitigation: treat as “enabled but unhealthy” (`onIdle` or dimmed), still visible so operators know the radio was left on.
- **[Risk] Strip refactor regresses camera layout** → Mitigation: widget tests for presence/phases; keep camera rightmost; reuse existing size scale.
- **[Trade-off] App-local vs cyber_ui** → Faster delivery; promote to CyberUI later if Monitor needs the same strip.

## Migration Plan

1. Land strip widget hosting camera only (layout-equivalent).
2. Add Wi‑Fi / BT icons + mappers + tests.
3. Update Home to position the strip; remove lone camera `Positioned`.
4. No rootfs/HAL rebuild beyond App push.

Rollback: revert App Home presentation; platform radios unchanged.

## Open Questions

- None blocking: tap-to-Settings deferred; exact dBm→bars thresholds can use simple Material defaults during implement.
