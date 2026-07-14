## 1. Scaffolding & asset

- [x] 1.1 Create `lib/platform/{audio,backlight,display}/` package layout per design D1
- [x] 1.2 Copy lws-ui `res/raw/shanghai_tan.mp3` → `app/hmi/assets/audio/shanghai_tan.mp3`; declare in `pubspec.yaml` assets
- [x] 1.3 Add any Flutter audio dependency chosen after D2 spike (or document Process/mpg123-only path with no Dart plugin)

## 2. Platform modules

- [x] 2.1 Implement abstract `MediaAudioController` + Linux backend (ALSA plugin or Process helper); clamp volume 0–100; play/stop asset
- [x] 2.2 Implement abstract `BacklightController` + Linux sysfs backend (`/sys/class/backlight/*/brightness`); clamp percent 0–100
- [x] 2.3 Implement display orientation enum + persist file (`/var/lib/lws-hmi/display-orientation`) + apply/restart hook mapping landscape→`landscape_left`, portrait→`portrait_up`
- [x] 2.4 Unit tests on host: percent clamps, orientation mapping, default landscape when file missing

## 3. Launch path & rootfs

- [x] 3.1 Update `hmi-launch.sh` to read orientation preference and pass mapped flutter-pi `-o` (default `landscape_left`)
- [x] 3.2 Enable minimal ALSA userland in Buildroot fragment / defconfig; ensure mixer (+ player if needed) lands in rootfs
- [x] 3.3 Ensure HMI can access backlight sysfs and audio devices (permissions/udev as required)

## 4. Demo UI

- [x] 4.1 Extend P2 demo page: Play/Stop for shanghai tan + volume slider wired to `MediaAudioController`
- [x] 4.2 Add brightness slider wired to `BacklightController`; init from get after first frame
- [x] 4.3 Add exclusive Portrait / Landscape controls wired to orientation API (may restart HMI)
- [x] 4.4 Keep first-frame path free of audio/backlight/orientation I/O (post-frame init; failures non-fatal)

## 5. Verify & docs

- [x] 5.1 `flutter analyze` / unit tests under `app/hmi/`
- [x] 5.2 Device smoke: play track, sweep volume, sweep brightness, toggle orientation and confirm after HMI restart
- [x] 5.3 Update `docs/flutter-pi-hmi-plan.md` §12 P2.1 checklist for audio / backlight / orientation items covered by this change
- [x] 5.4 Record resolved open questions (backlight node path, ALSA control, amp GPIO if any) in change notes or brief app README section
