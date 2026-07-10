# lws_hmi — P1 Hello World (flutter-pi)

## Engine alignment

Buildroot builds **flutter-pi** + **flutter-engine** from the SDK in-tree packages. Engine version is pinned in:

- `overlay/buildroot/flutter-engine.version`
- `overlay/buildroot/package/flutter-engine/flutter-engine.mk` (`FLUTTER_ENGINE_VERSION`)

Current pin: **Flutter 3.24.4**.

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
cd app/lws_hmi
flutter pub get
flutterpi_tool build --arch=arm64 --release
```

Or from repo root:

```bash
make build-flutter-app
make build-rootfs
make build-img
make flash
```

## Deploy layout on device

meta-flutter bundle (installed to `/opt/hmi`):

```
/opt/hmi/lib/libapp.so
/opt/hmi/lib/libflutter_engine.so
/opt/hmi/data/icudtl.dat
/opt/hmi/data/flutter_assets/
```

Started by `hmi.service`: `flutter-pi --release -o landscape_left /opt/hmi`

## ynh960 display

Panel is 800×1280 MIPI with `lcd0_rotation=90`. If the UI orientation is wrong on hardware, adjust `-o landscape_left` / `-r 90` in `hmi.service`.
