## Why

When the server pushes a single process parameter via WebSocket (`command.send_process_param`), the device persists it silently today. Operators have no confirmation of what was received or which values changed. A read-only summary dialog after successful persistence gives immediate visibility into remote updates without opening Engineer Mode.

## What Changes

- After a **successful** `command.send_process_param` persistence, enqueue a **`FrostedGlassDialog`** on the global **`AutoDialogQueue`** showing the received parameter summary.
- Dialog chrome: title indicating remote process-parameter delivery; body is a scrollable read-only parameter list; **only a confirm action**, labeled **OK** (`@string/ok_text`); no cancel button; dismiss on OK and optionally on scrim tap.
- List content **varies by `processType`** (continuous welding, spot welding, weld clean, width clean, hand cut, CNC cut), mirroring the **visible Engineer Mode fields** for that mode — not a flat dump of every DB column.
- Each row shows **label**, **formatted value**, and **unit** where Engineer Mode shows a unit (%, mm/in, Hz, ms, m/min, etc.), respecting the user's metric/imperial preference from `CommonSettings`.
- Introduce or reuse a **shared read-only list binder** built on **`InsetList` / `InsetListRow` / `InsetDivider`** (Settings list chrome) so the dialog body and future read-only summaries share one programmatic API.
- Extract **process-type → display row definitions** from duplicated Engineer Mode layout knowledge into a small shared builder (labels, value formatters, unit strings) consumed by the dialog.
- Do **not** show the dialog on persistence failure, malformed payload, or when boot self-check gate blocks auto dialogs (existing queue behavior).
- Do **not** change WebSocket ack semantics, payload shape, or DB persistence rules.

## Capabilities

### New Capabilities

- `remote-process-param-received-dialog`: User-visible confirmation after successful remote single process-parameter push, including dialog chrome, queue integration, process-type-specific row sets, and unit-aware formatting.

### Modified Capabilities

- `device-data-channel-abstraction`: Extend WebSocket `command.send_process_param` success handling with a normative operator notification requirement (dialog after successful persist).
- `frosted-glass-dialog`: Document the read-only parameter-list custom body pattern (OK-only confirm) as an approved `FrostedGlassDialog` use case.

## Impact

- **Code**: `DeviceWebSocketConnectionManager.handleInboundSendProcessParam` (post-success UI callback on main thread); new dialog presenter (e.g. `RemoteProcessParamReceivedDialog`); new shared list binder (e.g. `InsetLabelValueList` or `ReadOnlyParameterListBinder`); new process-parameter display row builder (e.g. `ProcessParameterDisplayRows`); `AutoDialogQueue` enqueue helper; optional strings for dialog title.
- **UI**: New frosted-glass custom body layout reusing `InsetList` row item layout; scroll when row count exceeds dialog height.
- **Tests**: Unit tests for process-type row selection, value/unit formatting, and dialog task id dedup policy.
- **Out of scope**: `command.send_process_lib` bulk library push notification; Engineer Mode live refresh of in-memory editing session; MQTT paths.
