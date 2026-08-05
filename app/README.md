# lws_hmi — P1 Hello World (embedded Linux HMI)

## Engine alignment

Buildroot ships the Flutter **engine** (and optional DRM runner) from in-tree packages. Engine version is pinned in:

- `overlay/buildroot/flutter-engine.version`
- `overlay/buildroot/package/flutter-engine/flutter-engine.mk` (`FLUTTER_ENGINE_VERSION`)

Current pin: **Flutter 3.41.9** (P5.1 triplet: SDK + engine + eLinux `42d3d75a56`). See [`docs/flutter-linux-hmi-plan.md` §6.5](../docs/flutter-linux-hmi-plan.md#65-flutter-engine-版本策略与升级p51). UI kit: **CyberUI** (P3.0); platform: **Dart HAL package** (P3.1).

### Prefetch (before `make build-rootfs`)

```bash
make build-deps        # build-dev-deps + runtime prebuilt
# or clone with prebuilt/ committed:
make check-prebuilt
```

- **Runtime** (`make build-runtime-deps`): flutter-engine, display runners, **gstreamer (MPP+RTSP)**, OpenCV sources, `prebuilt/rknn-rt`
- **MediaMTX** (product): `make build-mediamtx` → `prebuilt/`; shipped as `/opt/hmi/bin/mediamtx` by `make build-app` (App `cyber_pm` child — not rootfs)
- **AI daemon** (product): `make build-opencv` + `make build-ai` → `prebuilt/`; shipped as `/opt/hmi/bin/lws_ai_daemon` (+ `/opt/hmi/lib`) by `make build-app` (`cyber_pm` + `/run/hmi/ai` socks — not rootfs)
- **Dev host** (`make build-dev-deps`): `FLUTTER_SDK`, RKNN-Toolkit（仅 x86 转模型）
- **`make build-rootfs`** 安装 defconfig 已接入的 prebuilt；`check-prebuilt` 校验全部 runtime 项

Version pins in `overlay/buildroot/flutter-*.version`.

Host app builds use **`make build-app`** (`flutter assemble` + `gen_snapshot`, meta-flutter layout, matching Buildroot `FILESYSTEM_LAYOUT=meta-flutter`):

```bash
make build-app
```

Or from repo root:

```bash
make build-app   # libapp.so + assets → overlay /opt/hmi (any APP=*_hmi; default lws_hmi)
# APP=cnc_hmi make build-app          # also → /opt/hmi (replaces previous HMI in overlay)
# APP=factory_test make build-app     # → overlay /opt/factory_test
```

**Must use pinned Flutter `3.41.9`** (`make fetch-flutter-sdk`); `build-app.sh` refuses a mismatched SDK. AOT `libapp.so` and rootfs `libflutter_engine.so` **must be the same engine version** or the HMI exits/hangs with little or no UI.

```bash
make build-rootfs        # installs flutter-engine to /usr/lib (prebuilt)
make build-img
make flash
```

`libflutter_engine.so` and `icudtl.dat` are **rootfs-only** (`/usr/lib`, `/usr/share/flutter`). The display runner loads the engine via `dlopen` when it is absent from the bundle. App updates (`build-app`) do not touch the engine.

## Deploy layout on device

App bundle (`/opt/hmi` — updated with `make build-app`):

```
/opt/hmi/lib/libapp.so
/opt/hmi/data/flutter_assets/
```

System runtime (rootfs — updated with `make build-rootfs`):

```
/usr/lib/libflutter_engine.so
/usr/share/flutter/release/data/icudtl.dat
/usr/share/flutter/icudtl.dat   → release/data/icudtl.dat
```

Started by `hmi.service`: `/usr/libexec/hmi/hmi-launch.sh` (release embedder from the image stack; debug payload: matching debug engine via `LD_LIBRARY_PATH`).

## P1.5 device debugging (USB-SSH)

Pinned toolchain: **Flutter 3.41.9** (`make fetch-flutter-sdk`). Debug/release via `flutter assemble`.

**Display stack:** `make debug-app` works on the **Weston** image (`flutter-wayland-client` + cached debug engine via `LD_LIBRARY_PATH`). Board overlay scripts must include this Weston debug path (`make apply-overlay` → `make build-rootfs` → `make upgrade` once if the board is older than this change). Restore release AOT with `make build-app` then `make push-app`.

One-time host setup:

```bash
make fetch-flutter-sdk
make debug-setup
```

Build debug staging (host):

```bash
make build-debug-app
```

Run on a physical ynh960 over USB-SSH (board needs P1.5 overlay scripts from a rootfs rebuild):

```bash
make debug-app                 # SN=... when multiple boards
```

VS Code / Cursor: open repo root `lws-hmi`, Run and Debug → **lws-hmi (USB-SSH debug)**. The pre-launch terminal runs `make prepare-debug-host` and may request the macOS `sudo` password before Flutter starts; custom-device hooks themselves are non-interactive. Set `dart.flutterSdkPath` to `flutter-sdk`. `dart.analysisExcludedFolders` in `.vscode/settings.json` keeps SDK sources out of the Problems panel. Never run `flutter upgrade` inside `flutter-sdk/`; if compile breaks in framework sources, run `git -C flutter-sdk reset --hard HEAD` or `make fetch-flutter-sdk`.

Behavior:

- First debug session uploads the debug engine to `/var/lib/hmi/debug-runtime/<version>/` (large; cached afterward).
- `/opt/hmi` is replaced with the debug bundle (`kernel_blob.bin`); IDE stop keeps the debug app running.
- `hmi-launch` starts Weston + `flutter-wayland-client` with the cached debug engine; ICU is at `/opt/hmi/data/icudtl.dat`.
- Return to release: `make build-app` then `make push-app`.

Debug engine prebuilt lives at `prebuilt/flutter-engine/<ver>/arm64-debug/` and **is committed** alongside `arm64-release` so clones can `make debug-app` without a multi-hour engine rebuild. Refresh both when bumping the Flutter pin:

```bash
FORCE=1 make build-flutter-engine
FLUTTER_ENGINE_RUNTIME_MODE=debug FORCE=1 make build-flutter-engine
```

Host smoke test (no device):

```bash
make test-debug-app
```

## P2 Modbus RTU + GPIO demo

Home route is the P2 demo (`lib/ui/demo/p2_demo_page.dart`, `MaterialApp.home`).

| Item | Value |
|------|--------|
| Serial | `/dev/ttyS5`, **115200 8-N-1**, slave `0x01`, FC **0x04** input registers |
| Serial backend | Linux: **PosixSerialPort** (`stty` + libc). Buildroot `libserialport` 0.1.1 fails `sp_open` on kernel 6.1 (`termiox` → ENOTTY); patch `overlay/buildroot/package/libserialport/0002-dont-check-termiox.patch` for next rootfs rebuild |
| Device SN | `/usr/bin/read-serial` (USB gadget iSerial source), not Modbus |
| Control Card Version | attribute `device.control_card_version` (input `0x0002`) |
| Laser / Wire / Gunhead SN | `0x0032`–`0x0033`, `0x0035`, `0x0038`–`0x0039` (lws-ui formatting) |
| Alarm temps (Monitor) | Motor / Motor Driver / Protective Mirror / Collimator — `0x0061`–`0x0064`, raw×0.1 °C |
| Machine Status gauges | Gas Pressure `telemetry.blow_pressure` @ `0x0060` (gauge **0–1500** kPa); Laser Current `telemetry.laser_current` @ `0x006F` (raw×0.1 A, gauge **0–100** A) — lws-ui parity |
| Machine Status tiles | `machine.laser_on` / `air_valve_on` / `safety_ground_lock` / `gun_switch_on` / `red_light_on` / `wire_feeding_on`; Camera via IP-camera session |
| Alarm history | SQLite `/var/lib/hmi/alarm-logs.db` → `/userdata/hmi/alarm-logs.db`, table `alarm_logs` (`code` / `content` / `timestamp` epoch ms / `level`; UI `YYYY-MM-DD HH:mm`; one row per rising insert; 90‑day prune) |
| C001 (comm fault) | Modbus aggregate `poll.health` (`slide_window` 5/3 default); override via `product.ini` `control_card_comm_alarm_mode` |
| RGB pins | 契约 **GPIO_5 / GPIO_4 / GPIO_7**（红/黄/绿）；路径 `/sys/class/gpio_innohi/GPIO_N/value` |
| GPIO backend | 优先 `gpio_innohi`；经典 `/sys/class/gpio` 仅兜底（脚被占用时 export 会失败） |
| Rootfs | `BR2_PACKAGE_LIBSERIALPORT` via `overlay/buildroot/chips/lws_hmi_p2_io.config` |
| Permissions | `hmi.service` runs as root (access to ttyS5 + GPIO) |

Failed reads display `-`. LED rows default to **Off**; Steady / Blink (1 s on / 1 s off) / Off are mutually exclusive per color.

Rebuild notes: app-only → `make build-app` (+ `push-app`). First image after enabling `lws_hmi_p2_io.config` also needs rootfs rebuild so `libserialport.so` is present.

OpenSpec: `openspec/changes/p2-modbus-gpio/`.

## Troubleshooting (splash logo stuck)

1. On device: `diagnose-hmi` — check `journalctl -u hmi` for engine/AOT errors.
2. Common cause: **`libapp.so` built with wrong host Flutter** while rootfs engine is pinned **3.41.9**. Rebuild app with pinned SDK only:
   ```bash
   make fetch-flutter-sdk    # host; ensures flutter-sdk/ is 3.41.9
   make build-app
   make build-rootfs
   make build-img
   make flash
   ```
3. `verify-env` showing `WARN: eLinux not running` after boot → service crashed; see journal (version mismatch, missing icudtl, DRM).

## ynh960 display

Panel is 800×1280 MIPI with `lcd0_rotation=90`. If the UI orientation is wrong on hardware, adjust `-o landscape_left` / `-r 90` in `hmi.service`.
