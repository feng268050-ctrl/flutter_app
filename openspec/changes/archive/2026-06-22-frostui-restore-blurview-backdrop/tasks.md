## 1. OpenSpec & docs

- [x] 1.1 Archive proposal/design/specs for `frostui-restore-blurview-backdrop` after implementation
- [x] 1.2 Update `docs/frostui-dialog-backdrop-fix-guide.md`: primary path = live BlurView; remove §10 ban on BlurView; fallback = RenderScript snapshot only
- [x] 1.3 Update `docs/frostui-compose-refactor-design.md` §6.2 blur row to state BlurView is canonical (not snapshot+stack blur)

## 2. Shared BlurView support (`frostui/blur`)

- [x] 2.1 Add `FrostBlurViewSupport.kt` — extract from `HomeStatBlurSupport` (`setupBlurView`, `findSiblingBlurTarget`, `applyRoundedClip`, `BLUR_SCALE_FACTOR=3f`, triple-invalidate + `setBlurAutoUpdate(false)`)
- [x] 2.2 Refactor `HomeStatGlassCard` / `HomeStatBlurSupport` to delegate to `FrostBlurViewSupport` (no visual change) — superseded by §7 migration to `FrostCardView`; legacy classes deleted
- [x] 2.3 Make `FrostCaptureTarget` extend `BlurTarget` (or document migration to `BlurTarget` in layouts)

## 3. FrostCardView live BlurView

- [x] 3.1 Replace `staticBackdropImage` + `FrostStackBlur.blurAsync` primary path with `BlurView` in `staticBackdropLayer`
- [x] 3.2 Wire blur radius and overlay color from `FrostBlurIntensity` / `FrostBlurTint` to `BlurView` APIs
- [x] 3.3 Implement freeze: `setBlurAutoUpdate(false)` for dialog frozen / page frozen during overlay semantics
- [x] 3.4 Keep RenderScript snapshot fallback via `FrostBackdropCapture` + `FrostBackdropBlurRegistry` when `setupBlurView` fails
- [x] 3.5 Remove all `FrostStackBlur` imports and calls from `FrostCardView`

## 4. Registry, clock, overlay

- [x] 4.1 Remove `FrostStackBlur` default from `FrostBackdropBlurRegistry`; require app injection only
- [x] 4.2 Rewrite `FrostBitmapBlur` to delegate to `FrostBackdropBlurRegistry` (delete HokoBlur)
- [x] 4.3 Update `FrostHomeClockView` to use registry / live capture path per design
- [x] 4.4 Refactor `FrostOverlayHost` freeze path: prefer BlurView stop-update over full-screen CPU/RS re-blur on attach (`freezePageBackdropsDuringOverlay` → `FrostCardView.freezePageBackdropDuringOverlay`)
- [x] 4.5 Confirm `FrostUiDialogBridge` registers `BlurUtils.blurBitmap` (already present; add passes if needed)

## 5. Cleanup & dependency

- [x] 5.1 Delete `FrostStackBlur.kt`
- [x] 5.2 Update stale stack-blur references in docs (legacy `FrostedGlassBlurSupport` already deleted)
- [x] 5.3 Update `FrostPanelShell.kt`, `FrostBlur.kt`, `FrostBlurIntensity.kt` docs / naming (`blurViewRadiusPx` added; `stackBlurRadiusPx` deprecated alias)
- [x] 5.4 Remove `hoko-blur` from `gradle/libs.versions.toml` and `app/build.gradle.kts` if grep shows zero usage
- [x] 5.5 Update tests: remove stack-blur tests; adjust `FrostBitmapBlurInstrumentedTest` for RenderScript registry

## 6. Verification

- [x] 6.1 `ADB_SERIAL=emulator-5554 SKIP_BUNDLED_FETCH=1 make sync`
- [x] 6.2 Emulator: home stat cards blur (regression) — manual QA
- [x] 6.3 Emulator: simple `FrostDialog` prompt — live blur, no first-frame CPU stall — manual QA
- [x] 6.4 Emulator: boot self-check / IME text dialog — freeze without full-screen bitmap flash — manual QA
- [x] 6.5 Emulator: home clock minute tick — glyph blur intact — manual QA

## 7. Home stat cards → FrostCardView

Replace legacy `HomeStatGlassCard` on the home screen with unified `FrostCardView` (same blur stack as other frost cards via `FrostBlurViewSupport`).

- [x] 7.1 Map visual contract: `HomeStatGlassCard` uses `FrostBlurIntensity.LOW` + `FrostBlurTint.DARK`, no stack panel fill, sibling `BlurTarget` sampling — document equivalent `FrostCard` XML attrs (`frostedGlassBlurIntensity`, `frostedGlassBlurTint`, `frostedGlassStackPanelFill`, `frostedGlassCornerRadius`, `borderGradientCenter`)
- [x] 7.2 Replace 4× `HomeStatGlassCard` in `activity_main.xml` (`box_card1`–`box_card4`) with `FrostCardView`; preserve ids, padding, margins, `borderGradientCenter`, inner `static_1`–`static_4` hosts
- [x] 7.3 Remove `HomeStatGlassCard`-specific branches from `MainActivity` (`refreshFrostCardBackdropRecursive`, `freezePageBackdropsRecursive`, `unfreezePageBackdropsRecursive`) — `FrostCardView` paths already exist
- [x] 7.4 Delete `HomeStatGlassCard.java`, `HomeStatBlurSupport.java`, `home_stat_glass_attrs.xml` when grep shows zero references
- [x] 7.5 Update `activity_main.xml` BlurTarget comment (remove “dev 路径，非 FrostUI snapshot”)
- [x] 7.6 Emulator: home stat tiles blur against GIF backdrop; open/close frosted dialog — stat cards freeze/unfreeze without visual regression; compare to pre-migration baseline — manual QA
