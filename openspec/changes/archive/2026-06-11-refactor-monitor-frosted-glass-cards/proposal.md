## Why

Monitor tabs still rely on legacy `@mipmap` image backgrounds (`machine_static*`, `machine_data*`, `alarm_statuc_border`, `alarm_warn_border`, `video_process_bg`) for card and panel chrome. Settings has already migrated to reusable `FrostedGlassCard` / `FrostedGlassButton`, so Monitor now looks visually inconsistent and carries extra bitmap assets plus layout hacks (for example the horizontally mirrored `machine_static2` gauge background in `MachineStatusFragment`). Migrating Monitor to the shared FrostedGlass foundation aligns HMI chrome, reduces asset maintenance, and removes device-specific bitmap workarounds.

## What Changes

- Replace image-resource-backed card and panel containers across Monitor tabs with `FrostedGlassCard`, following the same patterns already used in Settings (`fragment_common_settings.xml`, `fragment_device_information.xml`).
- **Machine Status**: gauge panels and status tiles (`machine_static2`, `machine_static3`, `machine_data1`–`machine_data6`) become `FrostedGlassCard` containers; remove programmatic horizontal mirroring of `machine_static2` in `MachineStatusFragment`.
- **Alarm Information**: left scroll panel (`alarm_statuc_border`) and alarm/status tiles (`machine_data*`, `machine_static3`) become `FrostedGlassCard` containers.
- **Alarm Log** (embedded in Alarm tab): outer panel (`alarm_warn_border`) becomes `FrostedGlassCard`.
- **AI Vision**: work-mode info side panel (`video_process_bg`) becomes `FrostedGlassCard`.
- Preserve existing layout dimensions, padding, margins, data binding, checkbox semantics, and tab navigation behavior; this is a visual chrome refactor only.
- Remove Monitor-only dependencies on the replaced `@mipmap` card backgrounds once no longer referenced (subject to repo-wide dead-asset cleanup in implementation).

**Scope extensions (implemented during rollout, documented in spec deltas):**

- Work Information grid items (`item_ring`, `item_data`) → `FrostedGlassCard`.
- Unified Monitor page spacing via `frosted_glass_content_padding`; Alarm groups use `SectionHeader` / `SectionContent`.
- Alarm Log clear → `FrostedGlassButton`; AI Vision choose-video → `FrostedGlassButton`.
- AI Vision and Process Video Details video players → transparent `FrostedGlassCard` (replacing `video_content_box`).
- Process Video Details left panel → transparent `FrostedGlassCard` (replacing `video_process_bg`); delete → `FrostedGlassButton` secondary with Alarm Log clear icon.
- AI Vision / video parameter panels use transparent cards with edge-tight row content (no title divider on AI Vision work info).

## Capabilities

### New Capabilities
- `monitor-page-glass-cards`: Monitor tab card/panel chrome SHALL use `FrostedGlassCard` instead of legacy image backgrounds, with per-surface sizing and `borderGradientCenter` conventions documented for Machine Status gauges, status tiles, Alarm panels, Alarm Log, and AI Vision info panel.

### Modified Capabilities
- `monitor-machine-status-camera-card`: requirement text unchanged; Camera tile behavior stays the same but its container chrome moves from `machine_data4` image background to `FrostedGlassCard` like sibling tiles.

## Impact

- Layout XML under `app/src/main/res/layout/`: `fragment_machine_status.xml`, `fragment_warn_info.xml`, `fragment_warn_log.xml`, `fragment_ai_vision.xml`, `fragment_work_info.xml`, `item_ring.xml`, `item_data.xml`, `activity_process_video_details.xml`.
- Java: `MachineStatusFragment.java` (remove bitmap mirror helper); `WorkInfoFragment.java`, `StatAdapter.java` (Work Information spacing and gradients).
- Removed unused `@mipmap` / drawable chrome: in-scope Monitor card backgrounds and `video_content_box` player border; `video_process_bg` no longer referenced from `app/`.
- No API, Modbus, WebSocket, or data-model changes.
- Reuses existing `FrostedGlassCard` component and tokens from `frosted-glass-components` spec; no new UI component work required.
