## Context

`CameraController` (Fast / Engineer camera float) binds `isRecord` to `app:selectedState` on `camera_controller_btn`. Drawable selectors (`camera_orange_icon`, `camera_green_icon`, `camera_blue_icon`) switch between idle (`camera_stop_icon`) and recording (`camera_run_*_icon`). Starting a record runs `CameraRecordCoordinator.runStartPreflight()` which includes async `CameraUtils.checkCamera()` (ICMP ping).

Camera communication health is maintained separately:

- `CameraPingHealth` probes `CameraConfig.getCameraIp()` and commits reachability to `CacheKey.CAMERA_PING_REACHABLE`.
- `CameraCommStatus.isHealthy()` / `isFault()` wrap that flag.
- `CameraPingHealthScheduler` polls at 1 Hz after home entry; `WarnInfoFragment` already listens for UI updates.

The record button does not subscribe to comm health today. Operators only discover camera faults on tap (toast) or via Monitor C002.

**User constraint (explicit):** Unavailable styling is **not** true `View.setEnabled(false)`. The control stays clickable and shows **camera unavailable** feedback on tap—visual mute only.

## Goals / Non-Goals

**Goals:**

- Three distinguishable visuals: **available** (idle + comm OK), **unavailable** (idle + comm fault), **recording**.
- Drive available/unavailable from `CameraCommStatus` (same source as C002 ping health), refreshed on `CAMERA_PING_REACHABLE` changes and on attach.
- Unavailable tap: show existing `R.string.unable_to_open_the_camera_title` toast; do not call `runStartPreflight` or start timer/encoder.
- Recording state takes precedence: while `isRecord == true`, show recording visual even if ping fails; stop remains one tap.
- HTTP remote record (`CameraRecordUiBridge`) behavior unchanged; UI sync when float visible should reflect comm-unavailable idle visual when applicable.

**Non-Goals:**

- New alarm dialogs, strings (reuse existing camera-unavailable copy unless product requests dedicated record-button copy later).
- Changing ping interval, recovery debounce (`RECOVERY_STABLE_PINGS`), or C002 pipeline.
- Gating unavailable on storage / `isRecorderReady()` (comm-only per product ask); preflight still enforces those on successful start path.
- Emulator-specific bypass unless already required elsewhere.

## Decisions

### 1. Visual-only unavailable via custom binding attribute (not `enabled`)

**Choice:** Introduce a DataBinding variable `cameraCommAvailable` (or `recordVisualState` enum) and a new `@BindingAdapter` such as `app:commUnavailableState` on `ImageButton` that applies muted drawable/alpha **without** calling `setEnabled(false)`. Keep `camera_controller_root` **always clickable** except during in-flight preflight (existing brief disable during `checkAndStartRecord`).

**Alternatives considered:**

- `android:enabled=false` — rejected: blocks clicks and conflicts with user requirement.
- Separate overlay View — more layout churn; selector + binding adapter is enough.

**Rationale:** Matches “套了一层 UI”; click handler branches on `CameraCommStatus.isFault()` before start.

### 2. State resolution order

```
if (isRecord) → RECORDING visual
else if (CameraCommStatus.isFault()) → UNAVAILABLE visual
else → AVAILABLE visual
```

Recording never shows unavailable. Comm recovery uses existing 3-ping stable rule before flipping back to available.

### 3. Listen on `CAMERA_PING_REACHABLE` inside `CameraController`

**Choice:** Register `MemoryCacheManager.OnCacheChangedListener` in `onAttachedToWindow`, remove in `onDetachedFromWindow`, post `refreshRecordVisualState()` on main thread.

**Alternative:** Pull-only on each draw — rejected; misses updates while float visible.

Reference: same pattern as `WarnInfoFragment.updateCameraCommStatus()`.

### 4. Drawable selector structure

Extend each `camera_*_icon.xml`:

```xml
<item app:comm_unavailable="true" ... muted drawable />  <!-- via BindingAdapter, not XML -->
```

Because standard selectors lack a custom “comm unavailable” state, apply muted appearance in `BindingAdapter` (alpha ~0.35 on idle icon, or dedicated `@mipmap` if design provides). When `selected=true` (recording), binding adapter ignores unavailable mute.

**Alternative:** Layer-list with programmatic tint — acceptable fallback if selector ordering becomes awkward.

### 5. Click path

```java
onClick:
  if (isRecord) → stopRecord()
  else if (CameraCommStatus.isFault()) → ToastUtils.showShort(R.string.unable_to_open_the_camera_title)
  else → checkAndStartRecord()
```

No change to `CameraRecordCoordinator` preflight for the unavailable branch.

### 6. Preflight transient disable unchanged

`checkAndStartRecord()` may still `setEnabled(false)` on root during async preflight to prevent double-start. Restore enabled after callback; visual state refreshed separately.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Optimistic initial `reachable=true` shows available briefly before first failed ping | Accept existing ping module behavior; optional `probeAsync()` on attach if float opens before home monitor starts |
| Recovery lags 3 pings (~3s) | Document in QA; matches Monitor/C002 stability |
| `enabledState` adapter confusion | Do not bind `enabledState` for comm; document visual-only adapter in code comment |
| HTTP starts recording while UI shows unavailable | HTTP path bypasses button; preflight still runs camera check—consistent |

## Migration Plan

1. Ship drawable + binding + `CameraController` listener in one `make sync` build.
2. No data migration or config changes.
3. Rollback: revert binding variable and listener; selectors return to two-state.

## Open Questions

- None blocking implementation. If product later wants a **different** string than `unable_to_open_the_camera_title` for unavailable tap, add a dedicated string resource in a follow-up.
