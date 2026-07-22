## Why

Monitor and Settings still use a plain Material AppBar (back + title only), so operators lose Home’s connectivity glance and wall-clock time. Home’s strip and glyphs are App-local under `features/home/presentation/`, which blocks reuse by future CyberUI product packs. Promoting **icons, `CyberHomeStatusBar`, and `CyberPageStatusBar`** into `cyber_ui` gives one chrome kit; Apps only map HAL/session state and host routes. The Home status bar MUST be **extensible** — this product currently shows Wi‑Fi / Bluetooth / camera, but CyberUI MUST NOT hard-code a closed set of three slots.

## What Changes

- Add CyberUI **status icons** under `icons/` for the glyphs this product needs now (Wi‑Fi / Bluetooth / camera), each driven by UI status enums — not HAL types. New icon widgets MAY be added later without changing the `CyberHomeStatusBar` slot API.
- Add CyberUI **`CyberHomeStatusBar`** (Home-style right-aligned row) that accepts an **ordered list of status icon children/slots**, with consistent spacing — not a fixed three-parameter Wi‑Fi/BT/camera-only API. **Background MUST be transparent** (Home overlay on wallpaper).
- Add CyberUI **`CyberPageStatusBar`** (leading back, centered title, trailing **extensible** `CyberHomeStatusBar` + compact clock) for Monitor / Settings-style routes. **Background MUST adapt to the page’s primary/surface chrome color** (Theme-derived by default, with an optional explicit `backgroundColor` override).
- This product’s Home / Monitor / Settings currently compose **Wi‑Fi · Bluetooth · camera** (in that order) into `items`; future product icons (recording, lock, …) plug into the same API.
- Keep **HAL → UI-phase mapping and controller wiring in the App**. CyberUI accepts phases/callbacks/icon widgets only.
- Icons remain informational. Back uses click sound + App-supplied pop callback.

## Capabilities

### New Capabilities

- `app-page-status-bar`: This product’s Monitor / Settings adoption of the CyberUI page status bar (wiring, current three icons, camera session mapping, scaffold integration).

### Modified Capabilities

- `cyber-ui`: Add status icons (`icons/`), extensible `CyberHomeStatusBar`, and `CyberPageStatusBar` for cross-product reuse.
- `product-monitor-ui`: Monitor shell MUST use `CyberPageStatusBar`.
- `settings-ui`: Settings shell and Settings sub-page scaffold MUST use `CyberPageStatusBar`.
- `product-home-ui`: Home’s top-right strip MUST be `CyberHomeStatusBar` (not a feature-local fork); hero clock / Stack placement remain Home-specific.

## Impact

- **CyberUI:** `lib/src/icons/` + `lib/src/status_bar/` — icon widgets, extensible `CyberHomeStatusBar` (`items` / slots), `CyberPageStatusBar` + compact clock; package tests including “more than three icons” layout; export on `package:cyber_ui`.
- **App:** binders build the current icon list (Wi‑Fi · BT · camera) from mapped phases; host Home overlay and Monitor/Settings scaffolds; delete Home-local strip/icon forks.
- Out of scope: shipping additional product icons beyond the current three in this slice; Demo chrome; icon tap → Settings; frost hero `HomeClock` in the Home status bar; HAL inside `cyber_ui`.
