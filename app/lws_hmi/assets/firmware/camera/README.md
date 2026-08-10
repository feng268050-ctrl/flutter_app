# Camera firmware (source)

Checked-in `.zip` packages for **相机程序升级** (Product Home tip / Settings /
`make upgrade-camera` → CGI flash).

## Naming

`{MODEL}-v{SEMVER} build{YYYYMMDD}.zip` — model is alphanumeric; SemVer is
`X.Y.Z`; build is an eight-digit date; there is a **space** before `build`
(example: `LTC609-v1.0.7 build20260513.zip`).

## Multi-version

Keep **multiple** ZIPs in this directory (historical SemVer/build and/or
multiple models). `make prepare-app-assets` / `make build-app` copies **only
the newest package per model** (highest SemVer, then highest build) into
`assets/.generated/firmware/camera/` for the Flutter ship tree.

`make upgrade-camera` still reads **this source directory** (full history /
`FIRMWARE_ZIP=` override), not the generated ship tree.

## Runtime

At runtime the App lists the shipped assets and offers an upgrade only when
the bundled (SemVer, build) pair is strictly newer than the live camera
`appVersion` from `GET /System/deviceinfo`.

Do not place product/APK/rootfs OTA or control-board bins here.

## CGI upload payload

`POST /cgi-bin/cgic_upgrade` on Boa **`webServerPort` (80)** expects the inner
**`upgrade.tar.gz`** member (JSON API `httpPort` 9000 is for deviceinfo/reboot
only — POSTing CGI there resets the connection).

Vendor distribution ZIPs are wrappers; the App extracts `upgrade.tar.gz`
automatically before multipart upload (do not hand-edit the ship tree).
