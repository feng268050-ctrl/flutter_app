## 1. Package scaffold

- [x] 1.1 Create `packages/cyber_ime` with `pubspec.yaml` (`publish_to: none`, SDK aligned with `app/hmi`), `lib/cyber_ime.dart` barrel, README module map, and path wiring notes
- [x] 1.2 Define public types: `CyberImeFieldType`, session/spec APIs, `CyberImeAction`, language provider interface (`CyberIme*`)
- [x] 1.3 Add package analysis / test scaffolding (`flutter_test` or `test`) runnable from `packages/cyber_ime`

## 2. Field registry and session core

- [x] 2.1 Implement field-type registry mapping Text / Number / SignedDecimal / WiFi / Password (Email/Uri optional) → keyboard kind, bottom-row profile, numeric policy
- [x] 2.2 Implement session attach/detach with refcount-safe host signaling and exposed keyboard height (default lift margin 24)
- [x] 2.3 Implement commit path for insert / backspace / clear / enter against `TextEditingController` (or documented input-connection shim)
- [x] 2.4 Unit tests: registry selection for Number vs WiFi/Password; detach resets height to zero

## 3. Keyboard layouts

- [x] 3.1 Implement Keyboard A: QWERTY, primary `123` symbols, extended `#+=`, return via `ABC`; bottom-row profiles per registry
- [x] 3.2 Implement letter short-tap commit + long-press secondary popup where baseline requires it
- [x] 3.3 Implement Keyboard B: dedicated numeric pad (`1–9`, `⌫`, `C`, `-`, `.`, `0`, `00`, `⏎`) gated by `NumericPolicy` — no `abc` switch
- [x] 3.4 Add EnglishGlobal as default letter layout; document ChineseGlobal gap if deferred
- [x] 3.5 Widget/layout tests for A↔symbols toggle and B clear/enter keys
- [x] 3.6 (Optional track) Port ChineseGlobal letter caps / layout from lws-ui when assets ready; update README when parity claimed
  - Deferred: README documents EnglishGlobal-only v1; Chinese falls back to English until assets land

## 4. Overlay panel and hit-testing

- [x] 4.1 Build overlay keyboard panel sized to keyboard chrome only (no full-screen touch absorber)
- [x] 4.2 Wire show/hide lifecycle to session; ensure taps above the panel reach underlying content
- [x] 4.3 Bundle any key-cap fonts/assets; document in package README
  - v1 uses system/Material fonts; README notes assets path for ChineseGlobal

## 5. CyberUI dialog host composition

- [x] 5.1 Add lift hooks (or App adapter) so Cyber dialog / `CyberOverlayHost` translates the card by CyberIME keyboard height + margin without resizing the route scaffold
- [x] 5.2 Ensure dialog glass uses live or onChange refresh while keyboard is visible (no stuck pre-lift freeze)
- [x] 5.3 Widget or documented smoke: show dialog → focus field → keyboard → lift → dismiss → translation reset

## 6. App adoption (Settings priority)

- [x] 6.1 Add `app/hmi` path dependency on `cyber_ime`; register language provider at bootstrap
- [x] 6.2 Suppress system soft keyboard for CyberIME-managed fields on Linux HMI
- [x] 6.3 Adopt CyberIME on Settings Wi‑Fi password (connect) field
- [x] 6.4 Adopt CyberIME on HTTP proxy host and/or port fields
- [x] 6.5 Adopt CyberIME on at least one numeric Settings field
- [x] 6.6 Update `app/hmi` widget/navigation tests if they cover those Settings entry points
  - Existing nav tests do not open Wi‑Fi/proxy dialogs; no test changes required

## 7. Verification

- [x] 7.1 Run package tests + `flutter analyze` for `packages/cyber_ime` and touched App/CyberUI code
- [x] 7.2 Board smoke (`make build-app` / `make push-app`): Wi‑Fi password + proxy + numeric — focus → type → enter/dismiss → no stuck lift / no system IME
