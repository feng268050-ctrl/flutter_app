## 1. Machine Status layout and fragment cleanup

- [x] 1.1 Replace both gauge `FrameLayout` containers in `fragment_machine_status.xml` with `FrostedGlassCard` (`604×344dp`), preserving `@+id/leftGaugeCard`, padding, and `CircleProgressView` children; set left `borderGradientCenter="bottom-left-top-right"` and right `top-left-bottom-right`
- [x] 1.2 Replace all eight status tile outer containers in `fragment_machine_status.xml` with `FrostedGlassCard` (`290×102dp`, frosted fill, `borderGradientCenter="top-left-bottom-right"`), preserving labels, checkboxes, margins, and data bindings
- [x] 1.3 Remove `buildHorizontallyMirroredStatic2()` and background-setting logic from `MachineStatusFragment.initView()`; delete unused imports (`Bitmap`, `BitmapDrawable`, `BitmapFactory`, `Canvas`, `Matrix`, `Resources`)

## 2. Alarm Information and Alarm Log

- [x] 2.1 Replace the left scroll panel wrapper in `fragment_warn_info.xml` (`alarm_statuc_border`) with `FrostedGlassCard` (`frosted`, `borderGradientCenter="top-bottom"`), preserving scroll content and padding
- [x] 2.2 Replace all alarm metric tile containers in `fragment_warn_info.xml` (`machine_data*`, `machine_static3`) with `FrostedGlassCard` tiles matching Machine Status tile chrome
- [x] 2.3 Replace the outer panel in `fragment_warn_log.xml` (`alarm_warn_border`) with `FrostedGlassCard` (`frosted`, `borderGradientCenter="top-bottom"`), preserving title, list, and button layout

## 3. AI Vision

- [x] 3.1 Replace `layout_ai_info_panel` in `fragment_ai_vision.xml` (`video_process_bg`) with `FrostedGlassCard` (`360dp` width, frosted fill, `borderGradientCenter="top-left-bottom-right"`), preserving inner content and constraints

## 4. Verification and asset cleanup

- [x] 4.1 Build and install on emulator (`ADB_SERIAL=emulator-5554 SKIP_BUNDLED_FETCH=1 make sync`); visually verify Machine Status gauges/tiles, Alarm Information panel/tiles, Alarm Log panel, and AI Vision info panel
- [x] 4.2 Confirm Camera tile checkbox still reflects ping reachability on Machine Status
- [x] 4.3 Scan `app/` for references to `machine_static2`, `machine_static3`, `machine_data1`–`machine_data6`, `alarm_statuc_border`, `alarm_warn_border`, and `video_process_bg`; remove unreferenced `@mipmap` assets

## 5. Monitor spacing and shared section layout (scope extension)

- [x] 5.1 Apply `@dimen/frosted_glass_content_padding` page padding and consistent inter-panel gaps on Machine Status, Alarm Information, Work Information, and AI Vision
- [x] 5.2 Use `SectionHeader` / `SectionContent` for Alarm Information group cards and Alarm Log panel; wire divider spacing to `frosted_glass_content_padding`

## 6. Work Information FrostedGlass migration (scope extension)

- [x] 6.1 Migrate `item_ring.xml` and `item_data.xml` to `FrostedGlassCard`; apply grid spacing via `WorkInfoFragment` `RecyclerView` padding and `ItemDecoration`
- [x] 6.2 Update `StatAdapter` for column-aware `borderGradientCenter` on data cells

## 7. AI Vision and video chrome (scope extension)

- [x] 7.1 AI Vision info panel: `cardBackground="transparent"`, plain title (no `SectionHeader` divider), edge-tight label rows; card stretches with bottom whitespace; choose-video `FrostedGlassButton` at default height
- [x] 7.2 Replace AI Vision and Process Video Details `video_content_box` outer chrome with transparent `FrostedGlassCard` (`borderGradientCenter="bottom-left-top-right"`, `10dp` inner padding)
- [x] 7.3 AI Vision choose-video: `FrostedGlassButton` primary (`top-left-bottom-right`)

## 8. Process Video Details FrostedGlass migration (scope extension)

- [x] 8.1 Replace left parameter panel `video_process_bg` in `activity_process_video_details.xml` with transparent `FrostedGlassCard` (`top-left-bottom-right`); preserve edge-tight parameter list layout
- [x] 8.2 Replace delete control with `FrostedGlassButton` secondary; icon `btn_icon_fixed_size` tinted `frosted_glass_button_secondary_text`
- [x] 8.3 Mirror layout conventions in `fragment_process_video_details.xml` stub where applicable

## 9. Final verification

- [x] 9.1 `make sync` on emulator after layout changes; confirm no remaining `app/` references to `video_process_bg`, `video_content_box`, or in-scope legacy Monitor `@mipmap` card assets
