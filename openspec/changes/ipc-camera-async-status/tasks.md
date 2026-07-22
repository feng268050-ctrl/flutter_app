## 1. HAL `ip_camera` (portable)

- [x] 1.1 Add `package:cyber_hal/ip_camera.dart` with `IpCameraController`, `IpCameraStreams`, `IpCameraHealth` (+ optional suspend/resume probes)
- [x] 1.2 Linux backend: HAL-owned ICMP health policy (quiet-friendly, 3× recovery, 3× failure debounce, coalesce); no eth0/MediaMTX in this type
- [x] 1.3 Constructor takes required `cameraHost` (+ optional stream paths / probe); stub/fake backends; no singleton host
- [x] 1.4 Unit tests: health transitions; two instances with different hosts do not share state
- [x] 1.5 Document that path (eth0/Wi‑Fi/internet) is out of HAL scope; multi-instance is supported

## 2. Overlay helpers (this product)

- [x] 2.1 Dedicated eth0 path via **Ethernet HAL** (`setInterfaceEnabled` + `setIpv4Config`) + Dart address planner (no `configure-camera-eth0.sh`)
- [x] 2.2 Real `render-mediamtx-config.sh` for PR0/PR1 → `camera/pr0|pr1`
- [x] 2.3 Keep `mediamtx.service` on-demand; polkit/sudoers if needed for HMI `systemctl`

## 3. App product session (LWS topology + MediaMTX + UI)

- [x] 3.1 Implement `IpCameraProductSession` composing one HAL `ip_camera` (host from `ProductInfo.cameraIp()` / default) + eth0 path + MediaMTX
- [x] 3.2 Event-driven reconfigure from `EthernetController.link` / `WifiController.connection` (debounce); attempt budget → connecting/connected/failed
- [x] 3.3 On healthy+path-ready: start MediaMTX with upstream from `camera.streams`; on loss: stop
- [x] 3.4 Wire into `AppServices`; Home first-frame `start()`; Settings `ensureReady()`
- [x] 3.5 Session unit tests with fake path/relay/camera

## 4. Home + Settings UI

- [x] 4.1 Home top-right status icon bound to product session UI phase
- [x] 4.2 Remove Ethernet from Common Settings Network
- [x] 4.3 Add Input → IP Camera page shell, status rows, and transient establishing/failed placeholders
- [x] 4.4 Enable the active Buildroot GStreamer RTSP fragment (or prebuilt equivalent), Rockchip MPP decode, and flutter-pi GStreamer video player plugin
- [x] 4.5 Add the Flutter `video_player` dependency/API compatible with the flutter-pi GStreamer plugin and implement a host-safe preview controller wrapper
- [x] 4.6 Replace the successful `IpCameraPreview` placeholder/URL text with a real video texture bound to `session.previewPr1`
- [x] 4.7 Implement player lifecycle and retry: initialize after relay running, wait for first frame, dispose on page exit, recreate after RTSP/decoder failure
- [x] 4.8 Add widget/controller tests proving ready state renders the player surface (not a terminal placeholder) and host missing-plugin failure is non-fatal
- [x] 4.9 Build the Weston flutter-embedded-linux client with Sony's GStreamer `video_player` plugin and package `libvideo_player_plugin.so`
- [x] 4.10 Select the Linux video backend by display stack: register flutter-pi only outside Wayland and leave Weston to the eLinux native plugin

## 5. Boot self-check cleanup

- [x] 5.1 Remove Camera Comm from boot self-check; update tests
- [x] 5.2 Allow product camera session during self-check (no competing modal)

## 6. Verification

- [x] 6.1 `flutter analyze` + HAL/App/player tests after live-preview integration
- [x] 6.2 Build/deploy GStreamer runtime and verify plugin registration plus MPP-backed RTSP decode on ynh960
- [ ] 6.3 Device: icon phases, stable MediaMTX, and sustained moving preview on both flutter-pi and Weston images
- [x] 6.4 Rebuild final app + rootfs and upgrade the device
- [x] 6.5 Build `build-rootfs` (default Weston) and verify the eLinux client/plugin dependencies plus local RTSP texture path

## 7. HAL recording + Settings demonstration

- [x] 7.1 Add portable recording request/status/result/controller APIs under `ip_camera`; expose one recorder per camera controller
- [x] 7.2 Implement Linux GStreamer encoded RTSP→MP4 recorder with preparing readiness, candidate retry, cancel, EOS finalize, and bounded timeouts
- [x] 7.3 Add stub recording controller and HAL tests for first-media readiness, retry, stop result, cancellation, and per-camera isolation
- [x] 7.4 Enable ISO MP4 mux runtime in the active GStreamer Buildroot fragment/prebuilt export
- [x] 7.5 Add the Settings demo path policy `/userdata/storage/Videos/movie/<day>/<timestamp>.mp4` and Record/Stop UI below preview using local PR0
- [x] 7.6 Add Settings/HAL tests proving preparing is not recording and successful stop reports the exact saved path without business-record side effects
- [ ] 7.7 Device: rebuild/push app, confirm playable MP4 under `/userdata/storage/Videos/movie/...` on ynh960 (host analyze/tests already green)
