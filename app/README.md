# lws_hmi — P1 Hello World (flutter-pi)

## Engine alignment

Buildroot builds **flutter-pi** + **flutter-engine** from the SDK in-tree packages. Engine version is pinned in:

- `overlay/buildroot/flutter-engine.version`
- `overlay/buildroot/package/flutter-engine/flutter-engine.mk` (`FLUTTER_ENGINE_VERSION`)

Current pin: **Flutter 3.24.4** (P1～P3). **P3.5** (before P4 FrostUI): bump SDK + engine + flutter-pi together per [`docs/flutter-pi-hmi-plan.md` §6.5](../docs/flutter-pi-hmi-plan.md#65-flutter-engine-版本策略与升级p35).

### Prefetch (before `make build-rootfs`)

```bash
make build-deps        # build-dev-deps + runtime prebuilt
# or clone with prebuilt/ committed:
make check-prebuilt
```

- **Runtime** (`make build-runtime-deps`): flutter-engine/pi, **gstreamer (MPP+RTSP)**, mediamtx, OpenCV sources, `prebuilt/rknn-rt`
- **Dev host** (`make build-dev-deps`): `FLUTTER_SDK`, RKNN-Toolkit（仅 x86 转模型）
- **`make build-rootfs`** 安装 defconfig 已接入的 prebuilt；`check-prebuilt` 校验全部 runtime 项

Version pins in `overlay/buildroot/flutter-*.version`.

Host app builds use **flutterpi_tool** (meta-flutter layout, matching Buildroot `FILESYSTEM_LAYOUT=meta-flutter`):

```bash
flutter pub global activate flutterpi_tool
cd app/hmi
flutter pub get
flutterpi_tool build --arch=arm64 --release
```

Or from repo root:

```bash
make build-app   # libapp.so + assets only → overlay /opt/hmi
```

**Must use pinned Flutter `3.24.4`** (`make fetch-flutter-sdk`); `build-app.sh` refuses a mismatched SDK (e.g. host `flutter` 3.41.x). AOT `libapp.so` and rootfs `libflutter_engine.so` **must be the same engine version** or flutter-pi exits/hangs with little or no UI.

```bash
make build-rootfs        # installs flutter-engine to /usr/lib (prebuilt)
make build-img
make flash
```

`libflutter_engine.so` and `icudtl.dat` are **rootfs-only** (`/usr/lib`, `/usr/share/flutter`). flutter-pi loads the engine via `dlopen` when it is absent from the bundle. App updates (`build-app`) do not touch the engine.

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

Started by `hmi.service`: `/usr/lib/lws-hmi/hmi-launch.sh` (release: `flutter-pi --release`; debug payload: matching debug engine via `LD_LIBRARY_PATH`).

## P1.5 device debugging (USB-SSH)

Pinned toolchain: **Flutter 3.24.4** + **flutterpi_tool 0.5.4** (see `overlay/buildroot/flutterpi_tool.version`). Debug and release use the **same Flutter version** but different runtime-mode engine binaries.

One-time host setup:

```bash
make fetch-flutter-sdk
make debug-setup
```

Build debug staging (host):

```bash
make build-app-debug
```

Run on a physical ynh960 over USB-SSH (board needs P1.5 overlay scripts from a rootfs rebuild):

```bash
make debug-app                 # SERIAL=... when multiple boards
```

VS Code / Cursor: open repo root `lws-hmi`, Run and Debug → **lws-hmi (USB-SSH debug)**. The pre-launch terminal runs `make usb-ssh-setup` and may request the macOS `sudo` password before Flutter starts; custom-device hooks themselves are non-interactive. Set `dart.flutterSdkPath` to `flutter-sdk`. `dart.analysisExcludedFolders` in `.vscode/settings.json` keeps SDK sources out of the Problems panel. Never run `flutter upgrade` inside `flutter-sdk/`; if compile breaks in framework sources, run `git -C flutter-sdk reset --hard HEAD` or `make fetch-flutter-sdk`.

Behavior:

- First debug session uploads the debug engine to `/var/lib/lws-hmi/debug-runtime/<version>/` (large; cached afterward).
- `/opt/hmi` is replaced with the debug bundle (`kernel_blob.bin`); IDE stop keeps the debug app running.
- Return to release: `make build-app` then `make push-app`.

Optional prebuilt debug engine (instead of flutterpi_tool cache):

```bash
FLUTTER_ENGINE_RUNTIME_MODE=debug make build-flutter-engine
```

Host smoke test (no device):

```bash
make test-debug-app
```

## Troubleshooting (splash logo stuck)

1. On device: `diagnose-hmi` — check `journalctl -u hmi` for engine/AOT errors.
2. Common cause: **`libapp.so` built with wrong host Flutter** (e.g. 3.41.x) while rootfs engine is **3.24.4**. Rebuild app with pinned SDK only:
   ```bash
   make fetch-flutter-sdk    # host; repopulates ~/Downloads/flutter-sdk-3.24.4/install
   make build-app
   make build-rootfs
   make build-img
   make flash
   ```
3. `verify-env` showing `WARN: flutter-pi not running` after boot → service crashed; see journal (version mismatch, missing icudtl, DRM).

## ynh960 display

Panel is 800×1280 MIPI with `lcd0_rotation=90`. If the UI orientation is wrong on hardware, adjust `-o landscape_left` / `-r 90` in `hmi.service`.
