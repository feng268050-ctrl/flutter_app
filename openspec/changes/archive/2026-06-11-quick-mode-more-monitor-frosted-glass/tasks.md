## 1. Machine status dialog layout — shared frosted components

- [x] 1.1 Replace both gauge `XUILinearLayout` containers in `fragment_machine_status_dialog.xml` with `MachineStatusGaugeCard` (`machineStatusVariant="dialog"`, frosted blur); preserve `@+id/left_circle_view_container` / `@+id/right_circle_view_container`; left `borderGradientCenter="bottom-left-top-right"`, right `top-left-bottom-right`; migrate padding via `MachineStatusChrome`
- [x] 1.2 Replace all six status tile `XUILinearLayout` wrappers with `MachineStatusStatusTile` (`machineStatusVariant="dialog"`, frosted blur, `borderGradientCenter="top-left-bottom-right"`), preserving `@+id/machine_status_item_*`, labels, margins, and `app:machineStatusChecked` bindings
- [x] 1.3 Dialog variant typography: black labels + `highlight_check_box`; `machine_status_dialog_circle_progress` black scale/value/desc colors for readability on light blurred wallpaper

## 2. MachineStatusDialogFragment cleanup

- [x] 2.1 Remove all `setRadiusAndShadow` calls from `MachineStatusDialogFragment.initView()`; keep `ARG_QUICK_MODE_MORE_MONITOR` clip-children workaround for gauge containers
- [x] 2.2 Remove unused imports (`SizeUtils` if no longer needed after shadow removal)

## 3. Buttons — FrostedGlassButton

- [x] 3.1 Replace `work_status_btn_confirm` in `work_status_dialog.xml` with `FrostedGlassButton` (`primary`, `570dp` width, `@string/i_understand_text`)
- [x] 3.2 Replace `more_monitor_btn` in `laser_progress.xml` with `FrostedGlassButton` (`default`, rounded shape, `drawableEnd` right arrow); remove `modelType`-based `pressure_monitoring_btn_*` background binding

## 4. Shared machine-status components (Monitor + dialog)

- [x] 4.1 Add `MachineStatusChrome`, `MachineStatusGaugeCard`, `MachineStatusStatusTile`, `MachineStatusBindingAdapter`; `machineStatusVariant` enum attr and dimension styles
- [x] 4.2 Refactor `fragment_machine_status.xml` to use shared components (`machineStatusVariant="monitor"`, transparent cards, white labels)
- [x] 4.3 Symmetric horizontal padding on status tiles (`frosted_glass_content_padding` both sides)

## 5. FrostedGlassCard backdrop blur

- [x] 5.1 Add `FrostedGlassBlurSupport` (BlurTarget resolution, dialog-window guard, blur setup, padding migration)
- [x] 5.2 Extend `FrostedGlassCard`: internal `BlurView`, blur-active path clears `PanelDrawable` when `frostedGlassStackPanelFill=false`, fallback panel when blur fails
- [x] 5.3 Wrap `work_status_dialog.xml` wallpaper in `@+id/frosted_glass_blur_target` for same-window sampling

## 6. FrostedGlassDialog single-layer prompt

- [x] 6.1 Remove outer `BlurView` from `dialog_frosted_glass_prompt.xml`; single root `FrostedGlassCard` with `frostedGlassStackPanelFill="true"`
- [x] 6.2 Simplify `FrostedGlassOverlayHost` (no `setupLiveBlur` on content); update input dialog IME anchors to `frosted_glass_content`
- [x] 6.3 Ensure machine-status dialog cards do **not** enable `frostedGlassStackPanelFill` (blur-only on light wallpaper)

## 7. Verification and asset cleanup

- [x] 7.1 Build and install on emulator (`ADB_SERIAL=emulator-5554 SKIP_BUNDLED_FETCH=1 make sync`); verify quick mode → More Monitor (blurred yellow-white cards), Monitor page (transparent cards), `FrostedGlassDialog` prompts
- [x] 7.2 Confirm Modbus-driven gauge values and six checkbox states still update correctly
- [x] 7.3 Remove unreferenced `pressure_monitoring_btn_{green,blue,orange}.xml`; keep `reminder_btn_confirm_border` (still used by `dialog_reminder.xml`)
