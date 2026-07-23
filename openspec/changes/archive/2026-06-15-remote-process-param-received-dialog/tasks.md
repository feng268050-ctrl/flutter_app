## 1. Shared read-only list component

- [x] 1.1 Add `LabelValueListItem` model (label, value, optional unit)
- [x] 1.2 Add `inset_label_value_row.xml` using `InsetListRow` with label / value / unit TextViews
- [x] 1.3 Implement `InsetLabelValueList` to bind items into `InsetList` with `InsetDivider` between rows
- [x] 1.4 Add `frosted_glass_body_readonly_parameter_list.xml` (`AppScrollView` + `InsetList` container)

## 2. Process-type display row builder

- [x] 2.1 Add `ProcessParameterDisplayRows.build(ProcessParametersData, boolean useMMUnit)` returning ordered `LabelValueListItem` list
- [x] 2.2 Map `CONTINUOUS_WELDING` rows from welding Engineer Mode visible fields (exclude spot-only T1/T2)
- [x] 2.3 Map `POINT_WELDING` rows including spot interval/duration with ms units
- [x] 2.4 Map `WELD_CLEAN` / `WIDTH_CLEAN` rows from wash Engineer Mode panel
- [x] 2.5 Map `HAND_CUT` / `CNC_CUT` rows from cutting Engineer Mode panel
- [x] 2.6 Reuse `ProcessParameterDisplayFormat`, `InchMillimeterUtils`, `EngineerWashConvert`, `MaterialDisplayNameUtils` for values and units

## 3. Dialog wrapper and queue integration

- [x] 3.1 Add string resource for dialog title (remote received + process type name)
- [x] 3.2 Implement `RemoteProcessParamReceivedDialog.show(...)` with FrostedGlass OK-only confirm
- [x] 3.3 Add `AutoDialogTask.PRIORITY_REMOTE_PROCESS_PARAM` and `AutoDialogQueue.enqueueRemoteProcessParamReceived(...)`
- [x] 3.4 Wire `DeviceWebSocketConnectionManager.handleInboundSendProcessParam` success path to enqueue dialog on main thread with persisted data snapshot

## 4. Tests and verification

- [x] 4.1 Unit test `ProcessParameterDisplayRows` per process type (row labels, units, continuous vs spot differences)
- [x] 4.2 Unit test imperial vs metric thickness/swing-width formatting
- [x] 4.3 Manual/emulator smoke: inject `command.send_process_param` for at least one welding, one clean, and one cut type; confirm FrostedGlass dialog with OK only and correct units
