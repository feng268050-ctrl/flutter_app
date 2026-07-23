## 1. Assets

- [x] 1.1 Copy `Desktop/LwsUI/nozzle-weld.png` → `app/src/main/res/drawable-nodpi/nozzle_weld.png`
- [x] 1.2 Copy `Desktop/LwsUI/nozzle-cut.png` → `app/src/main/res/drawable-nodpi/nozzle_cut.png`
- [x] 1.3 Copy `Desktop/LwsUI/nozzle-weld-path-clean.png` → `app/src/main/res/drawable-nodpi/nozzle_weld_path_clean.png`
- [x] 1.4 Copy `Desktop/LwsUI/nozzle-ultra-wide-clean.png` → `app/src/main/res/drawable-nodpi/nozzle_ultra_wide_clean.png`

## 2. Loader

- [x] 2.1 Add `NozzleReminderImageLoader` in `com.lasercyber.lws.ui.common.config` with `bind(ImageView, int processModel)` and `drawableIdFor(int)` mapping per `ModelConstant` groups (weld shared, cut shared, weld-path clean, ultra-wide clean)
- [x] 2.2 Mirror `FocusScaleRefImageLoader` blank/decode-failure behavior and logging

## 3. Dialog wiring

- [x] 3.1 In `dialog_reminder.xml`, add `@+id/iv_nozzle_reminder` on card 2 `ImageView` and remove static `android:src="@mipmap/open_laser_icon2"`
- [x] 3.2 In `ReminderExactDialog.bindNozzleTipCard`, call `NozzleReminderImageLoader.bind` on `iv_nozzle_reminder` with `processModel`

## 4. Verification

- [x] 4.1 Build app (`make build` or `make sync`)
- [x] 4.2 Manual: open Important Reminder in continuous weld, hand cut, weld-path clean, and ultra-wide clean; confirm card 2 shows matching illustration and existing localized text
- [x] 4.3 Manual: confirm card 1 and card 3 behavior unchanged
