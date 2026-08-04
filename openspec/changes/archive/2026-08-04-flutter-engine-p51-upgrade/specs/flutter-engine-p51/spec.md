## ADDED Requirements

### Requirement: Flutter triplet upgrades to 3.41.x for P5.1

The product SHALL pin host Flutter SDK, Buildroot/prebuilt **flutter-engine**, and **flutter-embedded-linux** as a matched triplet to Flutter **3.41.x**, with floor **≥ 3.41.0**. At implementation time the pin MUST be the newest published stable **3.41.x** tip available (proposal baseline **3.41.9**), unless a documented spike fallback is recorded. Shipped `libflutter_engine.so` and the SDK used to build `libapp.so` MUST report the same Flutter version lineage and MUST NOT remain **3.24.4**.

#### Scenario: version files leave 3.24.4

- **WHEN** a developer inspects `overlay/buildroot/flutter-sdk.version` and `overlay/buildroot/flutter-engine.version` after this change
- **THEN** both report a 3.41.x version ≥ 3.41.0 (not 3.24.4)

#### Scenario: device engine matches App AOT

- **WHEN** rootfs and `/opt/hmi` are deployed from the upgraded pins
- **THEN** rootfs `libflutter_engine.so` and App `libapp.so` are built for the same pinned Flutter 3.41.x engine

### Requirement: eLinux client is rebuilt for the new engine

`overlay/buildroot/flutter-embedded-linux.version` SHALL reference an eLinux commit/tag built and stamped against the P5.1 engine (including Wayland client and GStreamer video player plugin stamp when product preview requires it). Prebuilt install MUST provide `flutter-wayland-client` and required plugin libraries for the product image.

#### Scenario: eLinux prebuilt stamp present

- **WHEN** `make check-prebuilt` runs after the upgrade rebuilds
- **THEN** `prebuilt/flutter-embedded-linux/<new-pin>/` has `.lws-prebuilt` and, when GStreamer preview is enabled, `.lws-gstreamer-video-player`

### Requirement: Prebuilt rebuild order is mandatory

Changing Flutter pins MUST use the product fetch/build helpers (`fetch-flutter-sdk`, `fetch-flutter-engine`, `build-flutter-engine`, `build-flutter-embedded-linux`) so Buildroot prebuilt packages do not install stale 3.24.4 artifacts. `make build-rootfs` alone MUST NOT be treated as sufficient when prebuilt stamps would reuse the old triplet.

#### Scenario: force engine rebuild on pin bump

- **WHEN** developers change `flutter-engine.version` to 3.41.x
- **THEN** they produce a new `prebuilt/flutter-engine/<pin>/` tree before shipping rootfs

### Requirement: App and packages compile on the new SDK

`app/lws_hmi/` and in-repo path packages used by the HMI SHALL analyze and release-build cleanly with the pinned 3.41.x SDK. Agent/documentation Flutter API pins SHALL be updated from 3.24.4 to the new pin so contributors do not apply obsolete 3.24-only APIs.

#### Scenario: build-app succeeds on 3.41.x

- **WHEN** a developer runs `make build-app` after the SDK pin update and Dart migrations
- **THEN** the meta-flutter bundle is produced without SDK/engine version mismatch errors

### Requirement: Device and debug acceptance for P5.1

After upgrade, the product SHALL demonstrate: `hmi.service` launches Home UI; Settings camera preview still works when MediaMTX/GStreamer path is enabled; `make push-app` hot-swap works against the new rootfs engine; and `make debug-app` (or equivalent Custom Device) can attach on the new SDK/engine pair.

#### Scenario: Home launches after upgrade

- **WHEN** the upgraded rootfs is deployed to ynh960 and `hmi.service` is active
- **THEN** the product Home UI renders without engine/ICU missing-file failures

### Requirement: Roadmap P5.1 status is updated on acceptance

When acceptance criteria pass, `docs/flutter-linux-hmi-plan.md` (and README P5.1 dependency row as applicable) SHALL mark **P5.1** complete and document the locked 3.41.x + eLinux pins.

#### Scenario: plan table reflects completion

- **WHEN** P5.1 acceptance is signed off
- **THEN** the plan stage table no longer lists P5.1 as 🔲 for the engine upgrade deliverable
