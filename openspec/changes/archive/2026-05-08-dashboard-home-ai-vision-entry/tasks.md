## 1. Resources and localization

- [ ] 1.1 Add AI Vision drawable (vector or mipmap) from design asset; tint or layered styling to align with Monitor/Settings home icons.
- [ ] 1.2 Add `@string/` entries for **AI Vision** caption on home (`values` + `values-zh`, and mirror any other locales used for home shortcut labels).

## 2. Home layout (`activity_main.xml`)

- [ ] 2.1 Group **Monitor** and **Settings** in a horizontal container constrained to **`start`**; order **Monitor** then **Settings**; remove Settings-only **`layout_constraintRight_toRightOf`** parent anchoring from the Settings block when merged into the row.
- [ ] 2.2 Add **AI Vision** wide quick-action container anchored to **`end`** (prior Settings vertical band); inner width ~**2×** single tile width (`0dp` + constraints or `@dimen`); reuse `translucent_box_fff`; set `android:onClick="toPage"` and assign **new numeric tag** (e.g. **`5`** per design—confirm no clash with dormant tag `5` views).
- [ ] 2.3 Resolve overlap with guideline/margins on target resolution; adjust margins if AI Vision aligns with **`box_card4`** edge.

## 3. Navigation and deep link

- [ ] 3.1 In `DeviceMonitoringActivity`, define a public `Intent` extra (e.g. initial tab index); when provided and valid (**0–4**), sync `TopTabView` selection and **`ViewPager2`** to that index **after** adapter/tabs initialization.
- [ ] 3.2 Map **Monitor** (**tag `3`**) unchanged; map **Settings** (**tag `4`**) unchanged; map **AI Vision** tag to **`DeviceMonitoringActivity`** with extra **AI Vision tab index `4`** in `MainActivity.toPage`.
- [ ] 3.3 Mirror the **AI Vision** mapping in **`HomePage.toPage`** using the **same numeric index** for WebView bridge parity.

## 4. Verification

- [ ] 4.1 On device/emulator: home shows **Monitor | Settings | (wide) AI Vision** per spec ordering and proportions.
- [ ] 4.2 Tap **AI Vision**: lands on AI Vision fragment without manual tab tap; **Monitor** defaults unchanged; **Settings** opens **`DeviceSettingActivity`**.
- [ ] 4.3 Verify English and Chinese captions for AI Vision shortcut.
