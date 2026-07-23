## 1. Global Scrollbar Foundation

- [x] 1.1 Add a reusable global ScrollView component that preserves the Engineer Mode behavior of hiding scrollbars until the user scrolls
- [x] 1.2 Update `EngineerParameterScrollView` to inherit from or delegate to the reusable global ScrollView behavior
- [x] 1.3 Add a global vertical scrollbar style based on the Engineer Mode parameter panel baseline: vertical, `insideOverlay`, fading enabled, unified white rounded thumb, and no default visible track
- [x] 1.4 Refactor `engineer_scroll_view_style` to inherit the global scrollbar visuals while preserving Engineer Mode layout width, height, and margins

## 2. Engineer And Parameter Page Migration

- [x] 2.1 Update Engineer Mode parameter layouts (`fragment_engineer_cutting.xml`, `fragment_engineer_wash.xml`, `fragment_engineer_welding.xml`) to use the global scrollbar component/style without changing parameter rows or controls
- [x] 2.2 Update Advanced Settings and parameter detail scroll areas (`fragment_advanced_setting.xml`, `fragment_process_video_details.xml`, `activity_process_video_details.xml`) to use the global vertical scrollbar style
- [x] 2.3 Verify Engineer Mode and parameter setting interactions still open dialogs, validate input, save/reset, and navigate exactly as before

## 3. General Scrollable Page Migration

- [x] 3.1 Replace local scrollbar attributes in safety/use-safety tips, upgrade, and device information layouts with the global vertical scrollbar style
- [x] 3.2 Replace local scrollbar attributes in WiFi and Bluetooth scrollable layouts with the global vertical scrollbar style while preserving existing list behavior
- [x] 3.3 Search remaining page layouts for direct vertical scrollbar thumb/track/size/fade/style overrides and migrate any ordinary vertical page scroll containers to the global style

## 4. Resource Cleanup And Verification

- [x] 4.1 Remove unused `scrollbar_thumb_disclaimer` / `scrollbar_track_disclaimer` resources only after confirming no remaining references
- [x] 4.2 Run resource/lint or build verification for the touched Android UI module
- [x] 4.3 Manually verify or document verification for Engineer Mode parameter panels, Advanced Settings, safety tips, upgrade/device info, WiFi, and Bluetooth scroll behavior
