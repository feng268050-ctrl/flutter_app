## 1. Build and project setup

- [x] 1.1 Add Compose BOM, UI, Material3, activity-compose, and compose compiler plugin versions to `gradle/libs.versions.toml`
- [x] 1.2 Enable `buildFeatures.compose` and `composeOptions` in `app/build.gradle.kts`; verify `:app:assembleDebug` compiles
- [x] 1.3 Create `app/src/main/kotlin/com/lasercyber/lws/frostui/{border,card,dialog}/` package directories

## 2. Resource token split

- [x] 2.1 Extract `frosted_glass_*` colors into `app/src/main/res/values/frostui_colors.xml`
- [x] 2.2 Extract `frosted_glass_*` dimens into `app/src/main/res/values/frostui_dimens.xml`
- [x] 2.3 Extract related frosted-glass styles/attrs into dedicated `frostui_*` values files where applicable
- [x] 2.4 Add temporary aliases or update references so existing screens build during migration
- [x] 2.5 Wire `frostui.border` token accessors (`FrostColors`, `FrostDimens`) to split resource files

## 3. border package — drawing foundation

- [x] 3.1 Port `FrostedGlassBorderGradientCenter` to `frostui.border.BorderGradientCenter`
- [x] 3.2 Port tone/blur enums (`FrostTone`, `FrostBlurTint`, `FrostBlurIntensity`) to `frostui.border`
- [x] 3.3 Implement `PanelFillPainter` and `PanelBorderPainter` from `FrostedGlassPanelDrawable` logic (sweep/radial/linear + localized capsule borders)
- [x] 3.4 Expose Compose `Modifier` extensions for frost panel fill and border drawing
- [x] 3.5 Migrate or duplicate `FrostedGlassPanelDrawableInstrumentedTest` under frostui androidTest; achieve visual parity baseline
- [x] 3.6 Migrate `FrostedGlassBlurIntensityTest` to frostui unit tests

## 4. card package — components, blur, click sound

- [x] 4.1 Implement `FrostUiClickSound` and `FrostUiClickSoundRegistry` in `frostui.card`
- [x] 4.2 Register click sound in `LaserApplication` delegating to `GlobalSoundManager.playClickSound`
- [x] 4.3 Implement `FrostBlur` with `AndroidView` BlurView wrapper; define minimal `FrostEnvironment` injection if blur intensity needs app settings
- [x] 4.4 Implement `FrostCard` Composable (blur, fill, border, padding, `borderGradientCenter`, optional border/fill toggles)
- [x] 4.5 Implement `FrostButton` Composable (`default`/`primary`/`secondary`, shapes, localized capsule borders, click sound via Registry)
- [x] 4.6 Add `frostui.card.interop.FrostCardView` and `FrostButtonView` (`AbstractComposeView`) for Java/XML embedding

## 5. dialog package — overlay and prompt shell

- [x] 5.1 Implement `FrostOverlayState` and `FrostOverlayHost` (per-activity attach, scrim, dismiss, fade, activity destroy cleanup)
- [x] 5.2 Implement `FrostPromptDialog` Composable/shell with title, default Text body, and default confirm/cancel action row
- [x] 5.3 Support `customTitleView`, `customBodyView`, `customActionBarView` slots hosting Android Views
- [x] 5.4 Support `showConfirm(false)`, `dismissOnScrimClick`, `Handle` API (`dismiss`, `isShowing`, slot accessors, `findViewById`)
- [x] 5.5 Align overlay stacking and rejection semantics with existing `FrostedGlassOverlayHost` runtime behavior

## 6. ui facade — FrostedGlassDialog.prompt() migration

- [x] 6.1 Refactor `FrostedGlassDialog.prompt()` / `PromptBuilder` to delegate show/dismiss to `frostui.dialog`
- [x] 6.2 Verify `GlobalDialogUtil.showFrostedGlassPromptDialog(...)` works without API changes
- [x] 6.3 Verify simple confirm/cancel, cancel-only, scrim dismiss on/off, and callback semantics match pre-migration behavior
- [x] 6.4 Run emulator `make sync` visual check on representative prompt flows

## 7. Phase 3 — embedded page cards migration

- [x] 7.1 Migrate homepage QuickAction entries (`FrostedGlassQuickActionEntry` / related layouts) to `FrostCardView` or Compose embedding
- [x] 7.2 Migrate engineer mode Monitor frosted-glass cards to frostui interop/Compose
- [x] 7.3 Migrate other high-traffic inline `FrostedGlassCard` layouts identified by grep (dashboard, settings sections as applicable)
- [x] 7.4 Emulator visual regression on migrated card screens

## 8. Legacy cleanup

- [x] 8.1 Grep for remaining references to each `FrostedGlass*` View class; migrate or justify retention
- [x] 8.2 Delete unreferenced `FrostedGlass*.java` implementation classes under `ui.component.dialog` (`FrostedGlassCard` removed; `FrostedGlassButton`, dialog shell, blur support retained)
- [x] 8.3 Delete obsolete frosted-glass layouts/drawables only used by removed View implementations (none required after card removal)
- [x] 8.4 Remove temporary resource aliases once all references use `frostui_*` tokens
- [x] 8.5 Confirm no `frostui` source imports `com.lasercyber.lws.ui`

## 9. Verification and documentation

- [x] 9.1 Full `:app:assembleDebug` and unit/androidTest pass for frostui tests
- [x] 9.2 Manual click-sound check: `FrostButton` triggers settings-backed click sample via Registry
- [x] 9.3 Update `docs/frostui-compose-refactor-design.md` revision log if implementation diverges from design
- [x] 9.4 Archive-ready: all tasks complete, specs satisfied, no orphaned legacy FrostedGlass View chrome
