## Context

CyberUI Frost parity is archived; product Settings still use Flutter’s default text input / system soft keyboard path, which is a poor fit for flutter-pi HMI (no OEM IME, dialogs need card lift). lws-ui solved this with an **in-app custom keyboard overlay** (`com.lasercyber.lws.ime`), not `InputMethodService`. Reference: lws-ui `ime-custom-keyboard` / `ime-overlay-input` specs, `ime-keyboard-baseline.mdc`, and `docs/IME.md` (hit-testing pitfalls).

Constraints: Flutter 3.24 / flutter-pi on ynh960; Cyber dialog host already exists; path-package pattern like `cyber_ui` / `cyber_hal`; no dependency from `cyber_ime` → product App; optional hooks into CyberUI for lift/blur only.

## Goals / Non-Goals

**Goals:**

- Ship `packages/cyber_ime` with field-type registry, Keyboard A (global + symbol layers) and Keyboard B (numeric pad), overlay session lifecycle, and commit/backspace/enter.
- Compose with Cyber dialogs: lift focused card above keyboard; refresh or live-sample glass while keyboard is up.
- Adopt on Settings Wi‑Fi password + HTTP proxy (+ one numeric field) on ynh960; hide system soft input for those flows.
- Unit/widget tests for layout/registry; board smoke: focus → keyboard → type → dismiss without stuck lift.

**Non-Goals:**

- Full Pinyin candidate engine beyond what we choose for ChineseGlobal v1 (may phase Chinese glyphs).
- System IME / Android CyberIME backend.
- Migrating every Material `TextField` in the App in one change.
- Coupling IME to `cyber_hal` audio or Modbus.

## Decisions

1. **In-app overlay keyboard (not system IME)**  
   Match lws-ui: Flutter overlay panel owned by the App session. Flutter `TextInput` connection is driven by CyberIME commits (or a thin `TextEditingController` bridge), with system soft keyboard suppressed on Linux HMI.  
   *Alt rejected:* wrapping OEM IME — unavailable / inconsistent on flutter-pi.

2. **Path package `packages/cyber_ime` first**  
   Same as CyberUI v1; submodule/remote later. Public prefix `CyberIme*`.  
   *Alt rejected:* stuffing widgets into `cyber_ui` — package boundary already excludes IME.

3. **Field-type registry drives layout (baseline)**  
   `CyberImeFieldType` → profile → Keyboard A or B + bottom-row / numeric policy. Entry via `CyberImeOverlay` / session API keyed by field type — not scattered dialog `if`s. Align with lws-ui baseline (Text / Number / WiFi / Email / Uri / Password profiles; wire priority scenes first).

4. **Keyboard layouts**  
   - **A:** QWERTY + primary `123` symbols + extended `#+=` (iOS-like figures from baseline).  
   - **B:** Dedicated numeric pad (`1–9`, `⌫`, `C`, `-`, `.`, `0`, `00`, `⏎`) with `NumericPolicy`.  
   Language provider selects EnglishGlobal vs ChineseGlobal for type Text; **v1 MAY ship EnglishGlobal only** if Chinese assets lag — ChineseGlobal remains a tracked task, not silently dropped.

5. **Dialog lift + glass**  
   Overlay reports keyboard height; Cyber dialog/host applies translation to the card (margin ~24 logical px) without resizing the route scaffold. While keyboard visible, prefer **live** or **onChange refresh** for the dialog card sample so freeze-from-pre-lift does not misalign. Page-level cards MAY stay frozen.

6. **Touch host height = keyboard panel only**  
   Do not use full-screen absorbing layers (lws-ui `IME.md` failure mode). Pass-through above the panel.

7. **App integration order**  
   Bootstrap: register language provider + ensure system IME hidden for CyberIme fields. First call sites: Wi‑Fi password dialog/page, HTTP proxy fields, one numeric Settings field. Expand later.

## Risks / Trade-offs

- **[Hit-testing / overlay stack]** → Panel-sized touch host; no `overlayRoot` fallback; widget tests for hit targets.  
- **[Chinese fonts / layout]** → Phase ChineseGlobal; EnglishGlobal+Numeric ship first if needed.  
- **[Focus races with Cyber dialog dismiss]** → Session detach on dispose; refcount if stacked overlays.  
- **[flutter-pi TextInput quirks]** → Explicit suppress system keyboard; document embedder gaps in design notes if found.  
- **[Scope creep]** → Settings adoption list fixed in tasks; no full App TextField sweep.

## Migration Plan

1. Land package + tests (layouts, registry, session).  
2. Wire Cyber dialog lift hooks.  
3. App path dep + Wi‑Fi / proxy / numeric adoption.  
4. `make build-app` / `make push-app` board smoke.  
5. Rollback: remove App dependency and call sites; package can remain unused.

## Open Questions

1. Exact ChineseGlobal key caps / Pinyin — port lws-ui as-is or English-only v1?  
2. Prefer driving `TextEditingController` vs custom `TextInputConnection` shim on flutter-pi?  
3. Should `showCyberDialog` gain a first-class `imeFieldType` parameter, or composition-only wrappers in the App?
