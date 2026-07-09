# lws_hmi_app — P1 Hello World (flutter-pi)

## Engine alignment

Buildroot builds **flutter-pi** + **flutter-engine** from the SDK in-tree packages. Engine version is pinned in:

- `overlay/buildroot/flutter-engine.version`
- `overlay/buildroot/package/flutter-engine/flutter-engine.mk` (`FLUTTER_ENGINE_VERSION`)

Current pin: **Flutter 3.24.4**.

### Prefetch / prebuilt (before `make build-rootfs`)

```bash
make build-deps
```

- **Binaries** in git-tracked `prebuilt/` (engine, flutter-pi, host SDK when committed)
- **Sources** in `.cache/` only when compile fallback is needed
- Maintainer after one full rootfs: `make build-prebuilt` → commit `prebuilt/`

Version pins in `overlay/buildroot/flutter-*.version`.

Host app builds use **flutterpi_tool** (meta-flutter layout, matching Buildroot `FILESYSTEM_LAYOUT=meta-flutter`):

```bash
flutter pub global activate flutterpi_tool
cd app/lws_hmi_app
flutter pub get
flutterpi_tool build --arch=arm64 --release
```

Or from repo root:

```bash
make build-flutter-app
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
