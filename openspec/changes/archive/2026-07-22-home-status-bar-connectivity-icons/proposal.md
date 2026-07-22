## Why

Product Home already shows a top-right **camera** link icon, but that glyph is positioned ad-hoc — there is no shared **status-bar strip**. Operators still lack phone/desktop-like **Wi‑Fi** and **Bluetooth** indicators (hidden when the radio/adapter is off; distinct glyphs while connecting). Shipping connectivity icons without abstracting the strip would keep stacking one-off `Positioned` widgets and make later chrome (recording, remote lock, etc.) harder.

## What Changes

- Introduce a **Home status-bar region** (top-right) that owns layout/spacing for status glyphs and hosts the existing camera icon plus new connectivity icons.
- Show a **Wi‑Fi** status icon when the Wi‑Fi radio is enabled (`starting` / `on` / recoverable error while radio is conceptually on); **hide** when radio is **off**.
- Show a **Bluetooth** status icon when the BT adapter is enabled (`starting` / `on` / recoverable error while adapter is conceptually on); **hide** when adapter is **off**.
- Support **connecting / in-progress** visuals (and connected / idle-on styles) analogous to phone/laptop status bars, driven by existing `WifiController` / `BluetoothController` streams — no Settings navigation from the icons in this slice.
- Update Home specs so Wi‑Fi/BT status chrome is required (no longer “optional later”), while still deferring unrelated chrome (recording, remote lock).

## Capabilities

### New Capabilities

- _(none)_ — status-bar chrome stays under product Home; no new cross-product capability name.

### Modified Capabilities

- `product-home-ui`: Abstract the top-right Home status-bar strip; require Wi‑Fi and Bluetooth status icons with phone-like visibility and connecting states; keep camera icon as a strip child rather than a lone `Positioned` widget.

## Impact

- App Home presentation: new status-bar widget(s) under `features/home/presentation/`; refactor camera icon placement into the strip; subscribe to `AppServices.wifi` / `AppServices.bluetooth` after first paint (must not block Home first frame).
- Existing HAL APIs only (`WifiRadioState` / `WifiConnectionPhase`, `BluetoothAdapterState` + remote device connected flags) — no HAL surface change expected unless a small UI-phase mapping helper is added in App.
- Widget tests for strip visibility and icon phases; optional golden/smoke on Home.
- Design reference: lws-ui Home top-right Wi‑Fi slot; Material/icon-font composition preferred (same approach as camera status).
