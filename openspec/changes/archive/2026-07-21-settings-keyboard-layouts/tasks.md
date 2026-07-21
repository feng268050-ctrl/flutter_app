## 1. Product profile model

- [x] 1.1 Define shared product enum/profile (`ansiUs` / `isoDe` / `isoFr` / `jisJp`) with XKB id/model mapping and display labels
- [x] 1.2 Persist via existing `keyboard.conf` layout id (single source); map getLayout ↔ profile
- [x] 1.3 Unit tests for profile ↔ XKB id round-trip

## 2. HAL physical layouts

- [x] 2.1 Extend `LinuxKeyboard.listLayouts` with at least `us`, `de`, `fr`, `jp` (`jp106` model for JIS)
- [x] 2.2 Keep Demo-only `ru` available to Demo if needed; exclude from product Segment
- [x] 2.3 Update `keyboard_layout_test` for new list entries / conf encode

## 3. CyberIME regional Keyboard A

- [x] 3.1 Add unified `CyberImeKeyCode` + per-profile character maps (US/DE/FR/JIS); soft layouts consume maps only (no F-row / numpad chrome)
- [x] 3.2 Wire App profile provider so Keyboard A selects arrangement from current profile
- [x] 3.3 Document AltGr / JIS-special simplifications + soft/physical shared KeyMap contract in package README
- [x] 3.4 Widget tests: DE shows QWERTZ letter positions; panel has no F-row/numpad chrome

## 4. Settings Keyboard UI

- [x] 4.1 Replace Demo-primary Keyboard page with `CyberSegmentedControl` (US/DE/FR/JP) + profile name subtitle
- [x] 4.2 Show typewriter preview for selected segment (read-only CyberIME panel or dedicated preview)
- [x] 4.3 Operator note: physical keyboard must match selected specification
- [x] 4.4 Separate **Apply** (persist layout + update CyberIME, no auto-restart) and **Restart** (HMI restart + route restore to Keyboard page)
- [x] 4.5 Optional: keep HID presence line as secondary smoke info

## 5. Verification

- [x] 5.1 `flutter analyze` / tests for touched `cyber_hal`, `cyber_ime`, `app/hmi`
- [x] 5.2 Board smoke: Segment preview switches; apply DE/US; attach matching physical keyboard and check symbol keys; CyberIME password field follows profile
