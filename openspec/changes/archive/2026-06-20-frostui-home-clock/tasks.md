## 1. Dependencies and blur engine

- [x] 1.1 Add `io.github.hokofly:hoko-blur` (default **1.5.5**) to `libs.versions.toml` and `app/build.gradle.kts`
- [x] 1.2 Implement `frostui/blur/FrostBitmapBlur.kt` — `MODE_GAUSSIAN`, `sampleFactor(5f)`, `radius(25)`, `SCHEME_NATIVE` with `SCHEME_JAVA` fallback; support sync + `asyncBlur`
- [x] 1.3 Wire `FrostBackdropBlurRegistry` in `FrostUiDialogBridge` to HokoBlur (replace RenderScript `BlurUtils` for frost backdrop path)
- [x] 1.4 Unit tests: `FrostBitmapBlur` preserves dimensions, does not recycle input when `forceCopy(true)`

## 2. BlurTarget resolution (frostui-local)

- [x] 2.1 Implement `frostui/blur/FrostBlurTargetLocator.kt` — extract local `BlurTarget` lookup from `FrostedGlassBlurSupport.findLocalBlurTarget` (no `frostui` → `ui` dependency)
- [x] 2.2 Unit or instrumented test: locator finds sibling `BlurTarget` in a minimal view hierarchy

## 3. FrostHomeClock component

- [x] 3.1 Port glyph path, frost overlay, milk layer, edge highlight drawing from `FrostedGlassTextView` into `frostui/clock/FrostGlyphBlurRenderer.kt`
- [x] 3.2 Implement `frostui/clock/interop/FrostHomeClockView.kt` — backdrop capture at 1/5 scale, blur via `FrostBitmapBlur`, glyph-mask draw, gradient fallback
- [x] 3.3 Add `frostui` clock/glass tokens (`frostui_clock_*.xml` or reference existing `frosted_glass_light_*` until token migration)
- [x] 3.4 **Minute-key refresh**: remove periodic `postDelayed(1000)` / `backdropRefreshRunnable`; track `lastRenderedMinuteKey` (`hour*60+minute` or `HH:mm`); same minute → no capture, no `invalidate`
- [x] 3.5 **Event-driven capture**: recapture on `onAttachedToWindow`, `onSizeChanged`, and minute-key change; use `asyncBlur` + single `invalidate` when blur completes
- [x] 3.6 **Text short-circuit**: `updateTime` / `setText` — if formatted `HH:mm` unchanged, return without `requestLayout` or `invalidate`
- [x] 3.7 Expose `fun updateTime(millis: Long)` as the primary API for `MainActivity` binding

## 4. MainActivity binding — 方案 B（listener 仅在分钟变化时更新）

- [x] 4.1 Update `MainActivity.homeTimeUpdateListener`: format `HH:mm`, compare to `lastHomeClockMinuteText` (or `minuteKey`); **same minute → return early**
- [x] 4.2 On minute change only: call `binding.homeRealTime.updateTime(currentTime)` — **do not** call `setText` on every 1s `TimeGlobalManager` tick
- [x] 4.3 Verify NTP sync (`TimeGlobalManager.syncTimeWithWifi`) and `setCustomTime` still update clock when `HH:mm` changes mid-minute (not tied to second == 0)

## 5. Layout migration and cleanup

- [x] 5.1 Replace `FrostedGlassTextView` with `FrostHomeClockView` in `activity_main.xml` (`home_real_time` stays **outside** `BlurTarget`)
- [x] 5.2 Delete `FrostedGlassTextView.java`; grep verify zero production references
- [x] 5.3 Confirm `BlurUtils.java` remains for non-frost paths (quick mode, etc.) — out of scope to delete

## 6. Verification

- [x] 6.1 Run `:app:testDebugUnitTest` for `frostui.blur.*` and `frostui.clock.*`
- [x] 6.2 `ADB_SERIAL=emulator-5554 SKIP_BUNDLED_FETCH=1 make sync`; confirm clock updates on minute boundary and does not flicker/redraw every second
- [x] 6.3 Visual compare on real device `192.168.0.239:5555` — blur strength, glyph edges, frost tint vs legacy `FrostedGlassTextView`
