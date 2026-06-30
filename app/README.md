# lws_hmi_app — P1 Hello World (flutter-pi)

## Engine alignment

Buildroot ships in-tree **flutter-pi** and **flutter-engine** packages (see SDK `buildroot/package/flutter-pi/`). The pinned engine version in this SDK tree is **Flutter 3.24.4** (`FLUTTER_ENGINE_VERSION` in `flutter-engine.mk`).

Host builds use **flutterpi_tool** (meta-flutter bundle layout, matching Buildroot `FILESYSTEM_LAYOUT=meta-flutter`):

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
