## Context

Monitor (`DeviceMonitoringActivity`) exposes five tabs: Work Information, Machine Status, Alarm Information, Videos, and AI Vision. Machine Status, Alarm Information (including embedded Alarm Log), and AI Vision still use `@mipmap` bitmap backgrounds for card and panel chrome. Settings was recently refactored to `FrostedGlassCard` / `FrostedGlassButton` (`settings-page-structure` spec), establishing patterns in `fragment_common_settings.xml` and related layouts.

`FrostedGlassCard` (`com.lasercyber.lws.ui.component.dialog.FrostedGlassCard`) already provides frosted fill, gradient border, rounded clipping, and `borderGradientCenter` variants. Monitor must adopt it without changing Modbus bindings, ping-health semantics, or tab structure.

**Current image-backed surfaces (in scope):**

| Surface | Layout | Legacy asset |
| --- | --- | --- |
| Gauge panels (×2) | `fragment_machine_status.xml` | `machine_static2` (+ Java mirror on left) |
| Status tiles (×8) | `fragment_machine_status.xml` | `machine_data1`–`machine_data6`, `machine_static3` |
| Alarm left panel | `fragment_warn_info.xml` | `alarm_statuc_border` |
| Alarm metric tiles | `fragment_warn_info.xml` | `machine_data*`, `machine_static3` |
| Alarm log panel | `fragment_warn_log.xml` | `alarm_warn_border` |
| AI Vision info panel | `fragment_ai_vision.xml` | `video_process_bg` |

**Out of scope:** `DashboardFragment` (`custom_back*`) lives under Settings → Custom Home Page; Videos table head (`video_process_table_head_bg` drawable); Work Information tab (no image cards).

## Goals / Non-Goals

**Goals:**

- Replace every in-scope image-backed card/panel with `FrostedGlassCard` while preserving dimensions, padding, margins, and child hierarchy.
- Align Monitor visual chrome with Settings FrostedGlass tokens (`frosted_glass_corner_radius`, shared border gradients).
- Remove `MachineStatusFragment` bitmap-mirror workaround; achieve left/right gauge differentiation via `borderGradientCenter` instead.
- Delete unused `@mipmap` card assets after confirming no remaining references.

**Non-Goals:**

- Changing checkbox logic, alarm metric bindings, gauge values, or camera ping behavior.
- Migrating Videos table styling, Work Information layout, or Settings Custom Home Page (`DashboardFragment`).
- Adding new FrostedGlass component APIs or new shared XML includes (keep inline adoption like Settings).
- Redesigning grid structure, typography, or tab icons.

## Decisions

### 1. Direct XML replacement, not a new wrapper component

**Choice:** Replace `android:background="@mipmap/..."` containers with `FrostedGlassCard` in place, matching Settings layouts.

**Rationale:** Settings already demonstrates the pattern; a Monitor-specific wrapper would add indirection without reuse benefit.

**Alternative considered:** Extract `monitor_status_tile.xml` include — rejected to keep diff localized and avoid premature abstraction.

### 2. Preserve explicit dimensions on each card

**Choice:** Keep existing `layout_width` / `layout_height` (e.g. gauge `604×344dp`, tiles `290×102dp`, alarm log `468×608dp`) on the `FrostedGlassCard` root.

**Rationale:** Bitmap backgrounds previously defined visual bounds; explicit dimensions prevent wrap-content shrink after migration.

### 3. Gauge panel asymmetry via `borderGradientCenter`

**Choice:** Left gauge uses `borderGradientCenter="bottom-left-top-right"`; right gauge uses `top-left-bottom-right`. Both use default frosted fill (`cardBackground` omitted or `frosted`).

**Rationale:** Replaces the `buildHorizontallyMirroredStatic2()` hack with a token-driven visual distinction that scales across devices.

**Alternative considered:** Identical gradient on both sides — rejected because it loses the deliberate left/right visual pairing of the legacy design.

### 4. Status and alarm tiles use frosted fill with consistent gradient

**Choice:** All `290×102dp` status/alarm tiles use `FrostedGlassCard` with `app:borderGradientCenter="top-left-bottom-right"` and default frosted fill. Inner `LinearLayout` horizontal row (label + checkbox) becomes direct child; remove redundant outer `LinearLayout` only when it existed solely for `android:background`.

**Rationale:** Matches Settings grouped cards and unifies the eight Machine Status tiles with Alarm metric tiles.

### 5. Large panels use transparent or frosted fill by surface

| Panel | `cardBackground` | `borderGradientCenter` | Notes |
| --- | --- | --- | --- |
| Alarm left scroll wrapper | `frosted` | `top-bottom` | Replaces `alarm_statuc_border`; keep inner `padding="14dp"` on card or child |
| Alarm log outer panel | `frosted` | `top-bottom` | Replaces `alarm_warn_border` |
| AI Vision info panel | `transparent` | `top-left-bottom-right` | Replaces `video_process_bg`; edge-tight label rows; plain title (no section divider) |
| AI Vision / Video Details player | `transparent` | `bottom-left-top-right` | Replaces `video_content_box`; `10dp` inner padding |
| Process Video Details parameter panel | `transparent` | `top-left-bottom-right` | Replaces `video_process_bg`; edge-tight scroll rows |

**Rationale:** Settings uses `transparent` for list-row cards. Monitor parameter-style panels (AI Vision work info, video details left list) also use transparent fill so row label chrome can span card edges; frosted fill remains on dense dashboard tiles and Alarm Log outer shell.

### 5a. Scope extensions (implemented after initial proposal)

| Area | Change |
| --- | --- |
| Work Information | `item_ring` / `item_data` → `FrostedGlassCard`; grid spacing in `WorkInfoFragment` |
| Alarm Information | Left panel split into three group cards with `SectionHeader` / `SectionContent` |
| Alarm Log | Clear action → `FrostedGlassButton` primary |
| AI Vision | Choose-video → `FrostedGlassButton`; player → transparent `FrostedGlassCard` |
| Process Video Details | Left panel + player + delete → FrostedGlass components (activity outside Monitor tabs but shares video chrome) |
| Spacing | Unified `@dimen/frosted_glass_content_padding` on Monitor tab roots |

### 6. Remove `MachineStatusFragment.initView()` background logic

**Choice:** Delete `buildHorizontallyMirroredStatic2()` and the `leftGaugeCard.setBackground*` calls; both gauge containers are declared as `FrostedGlassCard` in XML.

**Rationale:** No runtime background mutation needed once XML owns chrome.

### 7. Asset cleanup gated on reference scan

**Choice:** After layout migration, `rg` for each legacy mipmap name across `app/`; remove only assets with zero references.

**Rationale:** Some assets may still be referenced outside Monitor (e.g. commented code, other modules).

## Risks / Trade-offs

- **[Visual parity drift]** FrostedGlass vector chrome may not pixel-match legacy bitmaps → Mitigation: keep dimensions/padding identical; verify on 1280×800 target resolution in emulator (`ADB_SERIAL=emulator-5554 SKIP_BUNDLED_FETCH=1 make sync`).
- **[Corner radius mismatch]** FrostedGlass uses `24dp` corner radius; legacy bitmaps may differ slightly → Mitigation: acceptable trade-off for design-system consistency; adjust padding if gauge clipping looks tight.
- **[Data binding IDs]** Wrapping containers may shift binding target IDs → Mitigation: preserve `@+id/leftGaugeCard` and other IDs on the `FrostedGlassCard` element.
- **[Premature asset deletion]** Removing mipmaps still used elsewhere → Mitigation: reference scan before delete.

## Migration Plan

1. Migrate `fragment_machine_status.xml` gauge and tile containers; simplify `MachineStatusFragment.java`.
2. Migrate `fragment_warn_info.xml` panel and tiles.
3. Migrate `fragment_warn_log.xml` outer panel.
4. Migrate `fragment_ai_vision.xml` info panel.
5. Build, install on emulator, visually verify all five Monitor tabs.
6. Remove unreferenced `@mipmap` assets.
7. Archive change; new spec `monitor-page-glass-cards` merges into `openspec/specs/`.

**Rollback:** Revert layout XML and `MachineStatusFragment.java`; no schema or data migration involved.

## Open Questions

- None blocking implementation. Gradient mapping per surface is defined above; adjust during visual QA only if a panel reads too flat against the black Monitor background.
