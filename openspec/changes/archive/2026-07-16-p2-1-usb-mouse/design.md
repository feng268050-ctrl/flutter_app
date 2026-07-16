## Context

P2.1 USB HID **keyboard** is done on the **1 mm host expansion** (and Micro-USB OTG host when Debug over USB is off). The same USB host stack already enumerates a USB **mouse**: libinput delivers motion/buttons/wheel, so Flutter can scroll — but flutter-pi’s **on-screen cursor** is missing (or fails silently) on ynh960.

Today’s flutter-pi path:

1. `LIBINPUT_DEVICE_CAP_POINTER` → enable cursor (`on_set_cursor_enabled`).
2. Motion → update compositor cursor pos + emit Flutter pointer events.
3. Visual cursor = **DRM hardware cursor** (`cursor_buffer_new` + `drmModeMoveCursor` / cursor plane).

Rockchip/Mali often breaks that HW cursor path (`Couldn't move mouse cursor. drmModeMoveCursor: Bad address`, stride/size requirements, or no usable cursor plane). Scroll still works because it never needs the cursor plane — only events.

Mouse “settings” are also not a product surface yet. flutter-pi hardcodes wheel scale (`scroll / 15.0 * 53.0`) and does **not** call libinput config APIs (natural scroll, accel, left-handed). P2.1 must expose these as **OS-shaped** Dart abstractions (like `BacklightController` / `DisplayOrientationController`), with a Linux backend that applies what the stack can support — not Demo-only widget hacks that vanish in P5 Settings.

## Goals / Non-Goals

**Goals:**

- USB HID mouse enumerates on existing host paths; motion / click / wheel reach Flutter.
- A **visible** pointer tracks the mouse whenever a pointer device is attached.
- Reusable `MouseSettingsController` (+ Linux impl) for OS-common prefs that spike confirms: **natural scroll**, **scroll speed**, **pointer speed (accel)**, **primary button (left/right)**.
- Demo section: presence, pointer smoke, settings wired to the controller; prefs under `/var/lib/lws-hmi/`.
- Prefs re-applied when flutter-pi / `hmi` starts (document in settings-persist schema).

**Non-Goals:**

- New USB host DTS (reuse keyboard / OTG host bring-up).
- Bluetooth / wireless mice; touchpad multi-finger gestures.
- Product Settings UI (P5.2) — Demo only here.
- Full cursor theme packs; custom PNG cursors beyond default arrow (+ system kinds if already plumbed).
- Double-click interval / dwell (Flutter-framework; defer unless free).
- Changing keyboard smoke or OTG Debug role behavior.

## Decisions

### D1 — Same host topology as keyboard; no new USB silicon work

**Choice:** Mouse smoke uses the **same** host paths as `linux-usb-hid-keyboard` (1 mm `usbhost_dwc3`; Micro-USB when Debug over USB off). Expect `CONFIG_USB_HID` / HID generic already sufficient.

**Alternatives:** Separate USB quirk table per mouse model — reject unless device-specific bugs appear.

### D2 — Visible pointer: fix compositor path first; software fallback if HW cursor is unusable

**Choice:** Spike on device:

1. Capture flutter-pi logs for `drmModeMoveCursor` / `cursor_buffer_new` / plane selection when a mouse is plugged.
2. If HW cursor can be fixed with a small flutter-pi or DRM buffer layout patch → prefer that (OS compositor owns the cursor).
3. If Rockchip cannot drive a cursor plane reliably → **software cursor fallback inside flutter-pi** (compose arrow into the Flutter/primary plane or overlay), still driven by existing `on_move_cursor` / `compositor_set_cursor`. Avoid a Demo-only Flutter `Listener` overlay as the primary OS solution (P5 would need to reinvent it).

**Alternatives considered:**

| Approach | Pros | Cons |
|----------|------|------|
| Flutter `MouseRegion` / custom paint overlay | Fast to Demo | Not OS-level; every app must opt in |
| Disable HW cursor + draw in Flutter engine | Works | Wrong layer |
| flutter-pi software cursor | One fix for all apps | Local patch to maintain |

### D3 — OS abstraction: `MouseSettingsController`, not Demo-only state

**Choice:** Mirror backlight / orientation:

```dart
abstract class MouseSettingsController {
  Future<MouseSettings> getSettings();
  Future<void> setSettings(MouseSettings settings); // persist + apply
  Future<void> dispose();
}
```

`MouseSettings` fields (v1, OS-common):

| Field | Meaning | Linux apply target |
|-------|---------|-------------------|
| `naturalScroll` | Invert vertical (and ideally horizontal) wheel | `libinput_device_config_scroll_set_natural_scroll_enabled` |
| `scrollSpeed` | 0–100% multiplier on wheel → Flutter delta | flutter-pi axis scale (replace hardcoded `15→53`) |
| `pointerSpeed` | 0–100% → libinput accel speed ∈ [-1, 1] | `libinput_device_config_accel_set_speed` |
| `pointerSize` | 0–100% visual cursor size (default 20) | flutter-pi icon density select + ceil/upscale (`0006`/`0007`) |
| `primaryButton` | `left` / `right` (left-handed) | `libinput_device_config_left_handed_set` |

Unsupported after spike → keep API but document `UnsupportedError` / disabled Demo control (do not fake).

**Alternatives:** Only `ScrollConfiguration` in Flutter — reject (does not change libinput / pointer accel / button swap at OS input layer).

### D4 — Apply path: persist file + flutter-pi apply (live preferred)

**Choice:**

- Persist: `/var/lib/lws-hmi/mouse.conf` (or sibling one-file-per-key matching existing prefs style). Prefer a single structured file (key=value or JSON lines) documented in `linux-settings-persist`.
- Apply: **flutter-pi patch** reads prefs at start, on pointer device-add, and via **1 Hz mtime poll** of `mouse.conf`. **Never** `kill -HUP` flutter-pi (default SIGHUP exits the process; `hmi.service` `Restart=on-failure` will not recover a clean stop).
- Dart `LinuxMouseSettingsController` **only writes** the file; MUST NOT decode HID or signal flutter-pi.

**Why not only Dart ScrollBehavior:** natural scroll and button swap must happen before Flutter sees events for OS-correct behavior.

### D5 — Demo UI: Mouse section after Keyboard, before Date & Time

**Choice:** `MouseDemoSection` with:

- Presence status (best-effort `/dev/input/by-id/*-mouse*` / `*-event-mouse*`).
- Short note: pointer must be visible when mouse attached; same USB host as keyboard.
- Controls: natural scroll switch, scroll speed slider, pointer speed slider, primary button toggle.
- Non-blocking init; failures non-fatal.

### D6 — Presence probe separate from settings (like keyboard)

**Choice:** `UsbHidMouseProbe` for status line only; settings controller does not own enumeration smoke.

### D7 — Settings-persist: document only (no new restore unit)

**Choice:** Mouse prefs are applied by flutter-pi at process start. Extend the **persist schema** list; do **not** add a new systemd restore oneshot (unlike Wi‑Fi). Reboot → `hmi.service` start → flutter-pi reads prefs.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| HW cursor plane broken on RK3566 | Spike early; commit to software cursor fallback in flutter-pi |
| libinput config not available on some devices | Query `*_is_available` before set; Demo disables control |
| Live apply without restart races with input thread | Apply under flutter-pi’s input path on device-add + HUP; document if restart required |
| Natural scroll + app ScrollPhysics double-invert | Apply only at libinput / flutter-pi; Demo must not also invert |
| Local flutter-pi patches accumulate | Number next patch `0004-…`; rebuild prebuilt via `make rebuild-flutter-pi` |
| Cursor shows with touch-only (false pointer cap) | Reuse flutter-pi’s existing pointer-vs-touch heuristics; smoke with real USB mouse |

## Migration Plan

1. Device spike: plug mouse → logs for cursor + `libinput list-devices` capabilities.
2. Cursor fix (HW or software) → rebuild flutter-pi → image.
3. Pref schema + flutter-pi apply for settings → Dart controller + Demo.
4. Operator smoke → §12 / ledger; archive change.

Rollback: revert flutter-pi patches + Demo section; mouse still scrolls without visible cursor (pre-change behavior).

## Open Questions

1. Does ynh960 DRM expose a usable cursor plane with correct buffer constraints, or is software cursor mandatory?
2. Can libinput accel / natural scroll / left-handed be applied live on hot-plugged mice without restarting flutter-pi?
3. Exact persist file format (single `mouse.conf` vs discrete files) — decide during implement to match neighbors under `/var/lib/lws-hmi/`.
