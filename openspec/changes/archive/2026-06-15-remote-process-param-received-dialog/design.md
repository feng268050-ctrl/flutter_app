## Context

WebSocket `command.send_process_param` is handled in `DeviceWebSocketConnectionManager.handleInboundSendProcessParam`: validate envelope, parse payload on a worker thread, persist via `ServerPushMessageHandler.saveProcessData`, then send `command.send_process_param_ack`. There is **no operator-facing confirmation** today.

Engineer Mode already defines **process-type-specific parameter panels** (`fragment_engineer_welding.xml`, `fragment_engineer_wash.xml`, `fragment_engineer_cutting.xml`) with label + value + unit rows. Settings pages recently standardized list chrome via **`InsetList` / `InsetListRow` / `InsetDivider`**. Remote WS prompts (forced disconnect, device registration) already use **`AutoDialogQueue.enqueueFrostedGlass`**.

## Goals / Non-Goals

**Goals:**

- Show a **`FrostedGlassDialog`** summary after **successful** remote single-parameter persistence.
- Dialog has **OK-only** confirm (`@string/ok_text`), no cancel.
- Body lists **process-type-specific fields** matching Engineer Mode visible rows, with **units**.
- Reuse **`InsetList`** programmatic binder for the read-only list (shared with future read-only summaries).
- Centralize row definitions in **`ProcessParameterDisplayRows`** (or equivalent) so Engineer Mode labels/formatters are not duplicated ad hoc in the dialog.
- Integrate with **`AutoDialogQueue`** so the prompt serializes with other auto dialogs and respects **`BootSelfCheckGate`**.

**Non-Goals:**

- Notification for `command.send_process_lib` bulk library push.
- Refreshing an active Engineer Mode in-memory editing session when a remote row arrives.
- Changing WS ack payload, persistence rules, or `ProcessParametersData` schema.
- Replacing Engineer Mode editable row layouts with the read-only list component.

## Decisions

### 1. Trigger point — post-success on main thread

**Decision:** After `saveProcessData` succeeds on the worker thread, `mainHandler.post(...)` enqueues the dialog with the parsed `ProcessParametersData` snapshot.

**Rationale:** UI must run on main thread; persistence stays off main thread. Failure paths (malformed payload, DB exception) skip the dialog and only send ack + telemetry.

**Alternative considered:** Show dialog before ack — rejected because operators should not see success UI if persist fails.

### 2. Dialog shell — FrostedGlassDialog OK-only

**Decision:** Feature wrapper `RemoteProcessParamReceivedDialog.show(context, data, onDismissed)` builds:

```java
FrostedGlassDialog.prompt(context)
    .title(R.string.remote_process_param_received_title) // includes process type name
    .customBodyView(R.layout.frosted_glass_body_readonly_parameter_list, ...)
    .showCancel(false)
    .showConfirm(true)
    .confirmText(R.string.ok_text)
    .dismissOnScrimClick(true)
    .onConfirm(onDismissed)
    .show();
```

**Rationale:** Matches `FrostedGlassStatusDialog` OK-only pattern and frosted-glass-dialog spec. Scrim dismiss aligns with informational (non-blocking) nature.

### 3. Shared list component — `InsetLabelValueList`

**Decision:** Add `InsetLabelValueList` under `com.lasercyber.lws.ui.component.layout`:

- Wraps `InsetList` inside scroll container when used in dialog body.
- Row model: `LabelValueListItem` (`label`, `value`, optional `unit`).
- Inflates `inset_label_value_row.xml` (`InsetListRow` + label TextView + value TextView + unit TextView).
- Inserts `InsetDivider` between rows (not after last).

**Rationale:** User asked for the abstracted generic list component; `InsetList` is already the Settings baseline. Programmatic API avoids duplicating XML per dialog.

**Alternative considered:** Reuse `engineer_data_row_style` layouts — rejected; those assume editable boxes and engineer-specific spacing.

### 4. Row catalog — `ProcessParameterDisplayRows`

**Decision:** New utility builds `List<LabelValueListItem>` from `ProcessParametersData` + `processType` + `useMMUnit`:

| Process type | Source layout | Row set (high level) |
|---|---|---|
| `CONTINUOUS_WELDING` | welding fragment | name, material, thickness, laser power, swing frequency, swing width, blow/close delays, wire feed, retract/fill fields, off-light delay, … (exclude spot-only T1/T2) |
| `POINT_WELDING` | welding fragment | same base + spot interval (T1) + spot duration (T2); exclude continuous-only ramp fields where hidden in UI |
| `WELD_CLEAN`, `WIDTH_CLEAN` | wash fragment | name, material, laser power, swing frequency, swing width, blow delay, air shut-off, slow rise/descent |
| `HAND_CUT`, `CNC_CUT` | cutting fragment | name, material, thickness, laser power, blow delay, air shut-off, slow rise/descent |

Formatting reuses **`ProcessParameterDisplayFormat`**, **`InchMillimeterUtils`**, **`EngineerWashConvert`**, **`MaterialDisplayNameUtils`** — same as `BaseProcessParametersDataViewModel` getters.

**Rationale:** Single catalog keeps dialog and future read-only views consistent with Engineer Mode.

**Alternative considered:** Reflect all non-null DB columns — rejected; product wants Engineer Mode parity, not raw dump.

### 5. Queue integration

**Decision:** Add `AutoDialogQueue.enqueueRemoteProcessParamReceived(context, ProcessParametersData data)` with:

- Task id: `ws:process_param_received:<rowId or correlation>` 
- Priority: `PRIORITY_REMOTE_PROCESS_PARAM = 45` (after bundled firmware 40, before forced disconnect 60)
- Policy: `SKIP_IF_PENDING` (rapid successive pushes coalesce to one queued dialog per id; latest payload wins if replaced)

**Rationale:** Consistent with other WS prompts; avoids stacking over alarms or boot flows.

### 6. Title and localization

**Decision:** Title format: localized string including process type label from `ModelConstant.getProcessTypeText(processType)` (e.g. "Remote process parameter received — Continuous Welding").

Parameter name shown as **first list row** (label `@string/params_name` or existing engineer equivalent), not only in title.

## Risks / Trade-offs

- **[Risk] Engineer Mode layout drift** — new engineer fields not added to `ProcessParameterDisplayRows` → dialog omits them. **Mitigation:** unit test per process type asserting minimum row count; comment in builder linking to source fragment.
- **[Risk] Dialog during safety-critical flow** — operator distracted mid-operation. **Mitigation:** informational only, OK/scrim dismiss; queue priority below forced disconnect and remote lock; no blocking of laser controls.
- **[Risk] Stale unit preference** — `useMMUnit` read from `CommonSettings` at show time may differ from server assumption. **Mitigation:** same as Engineer Mode (device-local unit setting governs display).
- **[Trade-off] No live Engineer session refresh** — remote row updates DB but open engineer editor keeps session baseline until user reloads. Acceptable per non-goals; document for support.

## Migration Plan

1. Ship app with dialog behind existing WS path (no server change).
2. Verify on emulator: inject `command.send_process_param` for each process type; confirm dialog rows and units.
3. Rollback: remove enqueue call; persistence/ack unchanged.

## Open Questions

- _(none blocking)_ — If product later wants suppressing dialog while Engineer Mode is foreground-editing the same row, add a guard comparing session row id vs received id.
