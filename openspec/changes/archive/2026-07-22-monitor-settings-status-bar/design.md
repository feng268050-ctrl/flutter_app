## Context

Home already ships a top-right **status icon strip** (`HomeStatusBar` + Wi‑Fi / BT / camera glyphs) under `features/home/presentation/`. Monitor and Settings use a plain Material `AppBar` (back + title) with no status icons or clock. Future product packs (and this product later) will add more status glyphs (recording, remote lock, …). CyberUI chrome must therefore treat icons as **composable slots**, while this App’s first adoption still wires the existing three.

## Goals / Non-Goals

**Goals:**

- Promote into `packages/cyber_ui` for reuse:
  1. **Status icons** (`icons/`) — state-driven widgets (start with Wi‑Fi / BT / camera)
  2. **`CyberHomeStatusBar`** — right-aligned row over an **extensible ordered list** of icon children; **transparent background**
  3. **`CyberPageStatusBar`** — back · centered title · Home status bar + compact clock; **background matches page chrome** (adaptive Theme default + optional override)
- This App maps HAL/session → UI phases and passes the current three icons into the strip.
- Strip/page-bar APIs MUST allow additional icons without API breakage or strip redesign.

**Non-Goals:**

- Implementing extra product icons beyond Wi‑Fi / BT / camera in this slice.
- Putting HAL / App session types into `cyber_ui`.
- Moving frost hero `HomeClock` into CyberUI.
- Demo chrome; icon tap → Settings; engineering system-status overlay.

## Decisions

### 1. Extensible strip first; product icon set is App composition

**Choice:** Primary strip API is slot-based, e.g.:

```dart
CyberHomeStatusBar(
  items: [ /* Widget status icons in display order */ ],
  gap: 12,
  iconSize: 28, // optional shared token; items MAY override
)
```

- CyberUI ships **individual** icon widgets (`CyberWifiStatusIcon`, …) as reusable building blocks.
- **This product** currently builds `items: [wifi, bluetooth, camera]` (left → right).
- Future icons are new `icons/` widgets (or App-local temporary glyphs) appended/inserted in `items` — strip layout code does not grow a new named parameter per glyph.

**Not:** `CyberHomeStatusBar({ required wifiPhase, required btPhase, required cameraStatus })` as the only public API (that freezes the set at three).

**Optional:** A thin product helper in the App (not required in CyberUI) that returns the current three-icon list — keeps CyberUI generic.

**Rationale:** User ask — icons will grow; don’t bake a closed triad into the bar.

### 2. Naming

**Choice:** Public names are **`CyberHomeStatusBar`** (Home overlay icon row) and **`CyberPageStatusBar`** (non-Home chrome) — not `CyberConnectivityStatusBar` / strip-only names. Keep Wi‑Fi shared phase enum name as connectivity-oriented (it still fits wifi/bt); camera keeps its own status type.

### 3. Three CyberUI layers; App only binds data

| CyberUI | Role |
|---------|------|
| Status icon widgets + UI enums | Per-glyph presentation |
| `CyberHomeStatusBar` | Layout/spacing over `items`; transparent background |
| `CyberPageStatusBar` | Back · title · strip + clock; Theme-adaptive / overridable background |

| App | Role |
|-----|------|
| HAL/session → phase mappers | Product data |
| Build `items` list (today: 3 icons) | Product icon policy / order |
| Home overlay host; Monitor/Settings scaffolds | Placement |

### 4. State-driven icons; callbacks not Navigator

**Choice:** Icons take UI enums + simple values. Page bar takes `VoidCallback? onBack`; play `CyberClickSoundRegistry.playClick` then `onBack`. No `Navigator` inside CyberUI. Hidden wifi/bt phases still shrink inside those icons so callers can leave them in `items` without gaps policy complexity (or callers MAY omit hidden icons — either is fine; prefer icon-internal shrink to match Home today).

### 5. Package layout

- `lib/src/icons/` — per-icon widgets, painters, spinner, phase enums
- `lib/src/status_bar/` — `CyberHomeStatusBar`, `CyberPageStatusBar`, compact clock
- Export from `lib/cyber_ui.dart`

### 6. Page status bar layout

```
┌──────────────────────────────────────────────────────────────┐
│ ← Back          Title              [ … status icons … ] HH:mm│
└──────────────────────────────────────────────────────────────┘
```

**Choice:** Trailing cluster = `CyberHomeStatusBar(items: …)` + compact clock. This product’s `items` are Wi‑Fi · BT · camera. Support `bottom` (TabBar) and optional `actions` before the far-right status+clock cluster.

### 7. Background treatment

**Choice:**

| Widget | Background |
|--------|------------|
| `CyberHomeStatusBar` | **Always transparent** — no fill/plate; sits over Home wallpaper/Stack. MUST NOT paint an opaque bar behind the icons. |
| `CyberPageStatusBar` | **Page chrome color** — default resolves from ambient Material theme (prefer `AppBarTheme.backgroundColor`, else `ColorScheme.surface` / scaffold-equivalent page primary). MUST also accept an optional explicit `backgroundColor` (or equivalent) so Apps can force a product page color without forking the widget. |

**Not:** Hard-coding only `Colors.black87` inside CyberUI with no Theme/override path; not giving Home status bar a frosted/opaque plate in this slice.

**Rationale:** Home is an overlay on rich wallpaper; Monitor/Settings need solid top chrome that matches the page’s main surface and must stay reusable when other products use different primaries.

### 8. Spec surface

**Choice:** `cyber-ui` requires extensible `CyberHomeStatusBar` + shipped starter icons + page-bar background rules. `app-page-status-bar` / Home / Monitor / Settings specify **this product’s current** three-icon composition and order without constraining CyberUI to only three forever.

## Risks / Trade-offs

- **[Risk] Long `items` crowds title** → Mitigation: ellipsis title; document density; products keep icon count modest.
- **[Risk] Apps rebuild full `items` every frame** → Mitigation: normal Flutter rebuild; phases are cheap widgets.
- **[Trade-off] Slightly more verbose than three named params** → Acceptable for extensibility; App helper can hide verbosity.

## Migration Plan

1. Port starter icons into `cyber_ui/icons`; package tests.
2. Add extensible `CyberHomeStatusBar` (transparent) + `CyberPageStatusBar` (+ clock, Theme/override background); tests with 3 icons **and** an extra placeholder item proving layout scales.
3. Home / Monitor / Settings adopt with current three-icon `items`.
4. Analyze + tests; archive.

## Open Questions

- None blocking: whether hidden icons stay in `items` (shrink) vs filtered by App — default shrink-in-icon.
