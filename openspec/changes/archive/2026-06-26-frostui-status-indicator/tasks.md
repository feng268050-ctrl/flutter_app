## 1. FrostUI status indicator primitive

- [x] 1.1 Add `FrostStatusState`, `FrostStatusVariant`, and appearance data class in `frostui.control`
- [x] 1.2 Add status colors/dimens to `frostui_control_colors.xml` and `frostui_control_dimens.xml` (idle gray, in-progress yellow, success green, failure red)
- [x] 1.3 Implement `FrostStatusIndicator` Compose with soft-edged background draw, Dot and Icon variants, 36dp size from `frost_status_indicator_size`
- [x] 1.4 Implement `FrostStatusIndicatorView` (`AbstractComposeView`) with styleables `frostStatusState` / `frostStatusVariant` and Java setters (`setState`, `setVariant`)
- [x] 1.5 Add unit tests for state × variant appearance mapping and background/dot geometry

## 2. Machine Status tile migration

- [x] 2.1 Refactor `MachineStatusStatusTile` to embed `FrostStatusIndicatorView` (**Dot** variant) instead of disabled `CheckBox`
- [x] 2.2 Remove `checkboxButtonDrawable` chrome; tile exposes `setIndicatorState`; `machineStatusChecked` maps on/off → Success/Idle at adapter layer
- [x] 2.3 Verify `fragment_machine_status.xml` and `fragment_machine_status_dialog.xml` need no structural changes beyond indicator class
- [x] 2.4 Update `MachineStatusChrome` to drop drawable references for checkbox button

## 3. Alarm Information migration

- [x] 3.1 Replace all status `CheckBox` elements in `fragment_warn_info.xml` with `FrostStatusIndicatorView` (**Icon** variant, 36dp)
- [x] 3.2 Retarget `CommStatusBindingAdapter` binding adapters to `FrostStatusIndicatorView` (`commStatus*`, `cameraCommStatus*`, `alarmMetric*`)
- [x] 3.3 Map `CommStatusDisplay` HEALTHY/FAULT/NEUTRAL → Success/Failure/Idle without changing resolution logic
- [x] 3.4 Add binding adapter unit tests for comm, camera comm, and metric tile mappings

## 4. Verification

- [x] 4.1 `make sync` on emulator-5554; visually verify Monitor → Machine Status on/off tiles (green/gray dots)
- [x] 4.2 Verify Alarm Information comm tiles (gray/green check/red cross) and temperature tiles (gray offline, green/red when ready)
- [x] 4.3 Verify quick-mode More Monitor dialog status tiles match Machine Status Dot variant
