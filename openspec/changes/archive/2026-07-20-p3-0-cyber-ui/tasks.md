## 1. Package scaffold

- [x] 1.1 Create `packages/cyber_ui/` with `pubspec.yaml` (`publish_to: none`, SDK ^3.5, flutter + flutter_lints), `analysis_options.yaml`, and README (module map, sample-mode defaults, theme seam)
- [x] 1.2 Add barrel exports (`lib/cyber_ui.dart`) and empty theme placeholder (`CyberGlassTheme` / ThemeExtension stub)
- [x] 1.3 Wire `app/hmi/pubspec.yaml` path dependency on `cyber_ui`; run `flutter pub get` in App and package

## 2. Blur primitives (lift from App)

- [x] 2.1 Move `CyberBlurSampleMode`, `CyberBlurIntensity`, `CyberBlurTint`, overlay resolve, `CyberBackdropBlurController` into `packages/cyber_ui`
- [x] 2.2 Move `CyberBlurBackdropScope` / `CyberBlurBackdropTarget` and `CyberBackdropBlur` into the package with widget tests for realtime / firstFrame / onChange
- [x] 2.3 Update App imports to `package:cyber_ui/...`; remove duplicated files under `app/hmi/lib/ui/cyber/` (keep thin re-exports only if needed during transition)

## 3. Core widgets

- [x] 3.1 Implement `CyberStatusIndicator` in cyber_ui (port from App stand-in); point Monitor wrappers at package
- [x] 3.2 Implement `CyberCard` (clip + `CyberBackdropBlur` + border/tint tokens) suitable for Home quick actions
- [x] 3.3 Migrate Home `HomeQuickAction` to `CyberCard` / package blur APIs with explicit `CyberBlurSampleMode.realtime`
- [x] 3.4 Add `showCyberDialog` / `CyberModal` skeleton with sample-mode parameter and fake-glass fallback (full lws-ui capture-policy parity deferred)

## 4. Click sound (UI SFX)

- [x] 4.1 Add `CyberClickSound` + `CyberClickSoundRegistry` (register / playClick; no-op if unregistered) with unit tests
- [x] 4.2 Wire `clickSoundEnabled` (default true) into `CyberCard` / `CyberButton` (and Home quick-action taps) to call `playClick()` on activate
- [x] 4.3 App bootstrap: register Linux/asset click backend (short clip; async; must not block UI); document that media volume remains `cyber_hal` / Settings
- [x] 4.4 Device smoke: hear click on Home quick-action tap after `make build-app` / `make push-app` (or document skip if audio path unavailable)
  - **Skip (host):** `make build-app` OK; `make push-app` blocked — USB-SSH iface needs `make setup-usb-ssh`. After setup: push, tap Home quick action, confirm click SFX.

## 5. App integration

- [x] 5.1 Ensure Home keeps `CyberBlurBackdropScope` + `CyberBlurBackdropTarget` around wallpaper/GIF stack
- [x] 5.2 Keep `HomeClock` in App (composition) but consume cyber_ui blur/theme tokens; document glyph-clip as App/clock concern until a stable Cyber clock API exists
- [x] 5.3 Settings: no forced glass rewrite; any new frost uses cyber_ui only
- [x] 5.4 Run `flutter analyze` + relevant App/package tests; device `make build-app` / `make push-app` smoke on ynh960 (Home glass + status + click)
  - Host: `packages/cyber_ui` + App analyze clean of errors; package tests + `app_navigation_test` pass; `make build-app` OK. Device push deferred (see 4.4).

## 6. Docs and closure

- [x] 6.1 Update package README with consumption rules (no bare `BackdropFilter` in features; chrome vs dialog sample-mode defaults; click registry registration)
- [x] 6.2 Note plan §6.3 alignment (realtime chrome default; dialogs MAY firstFrame) in cyber_ui README or a short pointer from `docs/flutter-pi-hmi-plan.md`
- [ ] 6.3 OpenSpec archive when implementation accepted (`/opsx:archive`)
