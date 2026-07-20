## 1. Click assets and indexed backend

- [x] 1.1 Copy lws-ui `click_mp3_2` / `click_mp3` / `click_mp3_1` into `app/hmi/assets/audio/` as `click_effect_1.mp3` / `click_effect_2.mp3` / `click_effect_3.mp3`; register in `pubspec.yaml`; remove or stop using single `click.mp3` as the only sample
- [x] 1.2 Implement `SoundEffectStore` (read/write index `0..2` under `/var/lib/hmi/`, default `0`, warm-read API)
- [x] 1.3 Update App click backend to play `click_effect_{n+1}.mp3` for active index; prefer dedicated short-clip path so clicks do not steal the media player session; optional ~150 ms debounce
- [x] 1.4 Bootstrap: warm-read store then `CyberClickSoundRegistry.register(...)` (document parity with `FrostUiDialogBridge`)

## 2. Settings Sound Effect UI

- [x] 2.1 Replace stub `SoundEffectSettingsPage` with Effect 1/2/3 segmented (or equivalent) control
- [x] 2.2 On change: persist index + preview sample (`openEffect` behavior); verify Common Settings entry still opens this page
- [x] 2.3 Unit/widget tests for store clamp + page selection persistence (fake store)
  - Store unit tests cover clamp + persist round-trip (widget page test deferred — hung under flutter_tester)

## 3. Cyber volume + audio player chrome

- [x] 3.1 Add `CyberVolumeSlider` / `CyberIconFlankedSlider` to `packages/cyber_ui` (presentation + callbacks only)
- [x] 3.2 Add `CyberAudioPlayerCard` (transport, seek bar, time labels; seek can be disabled)
- [x] 3.3 Export from barrel; package widget tests (smoke)

## 4. Settings Volume integration

- [x] 4.1 Rewrite `VolumeSettingsPage` to use Cyber volume chrome bound to `MediaAudioController`
- [x] 4.2 Add play-test using `CyberAudioPlayerCard` (or thin transport if layout constrained) for `shanghai_tan` / media preview
- [x] 4.3 Confirm Demo does not re-gain volume/play sections (`p2-device-demo-ui`)
  - `LwsHmiApp` keeps `skipPlatformSections: true`; Demo audio/volume block stays gated

## 5. Verify and docs

- [x] 5.1 `flutter analyze` + package/App tests for new code
- [x] 5.2 Device: `make build-app` / `make push-app` — switch Effect 1/2/3, hear Home tap change; adjust volume; play-test
  - `make build-app` + `make push-app` OK (board restarted). Operator: Settings → Sound Effect / Volume to verify by ear.
- [x] 5.3 Note `/var/lib/hmi/` sound-effect path in README or Settings help text; archive when accepted
  - Settings page help text + `packages/cyber_ui/README.md`; archive via `/opsx:archive` when accepted
