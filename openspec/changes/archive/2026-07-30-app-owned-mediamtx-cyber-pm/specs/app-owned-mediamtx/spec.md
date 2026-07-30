## ADDED Requirements

### Requirement: MediaMTX binary ships with the App bundle

`make build-app` (via the HMI bundle install path) SHALL install the prebuilt aarch64 MediaMTX binary at `/opt/hmi/bin/mediamtx` with the execute bit set, sourced from `prebuilt/mediamtx/linux-arm64/`. The build MUST fail with a clear hint to run `make build-mediamtx` when the prebuilt stamp or binary is missing. The binary MUST NOT be required in the rootfs overlay for product operation.

#### Scenario: Bundle contains mediamtx

- **WHEN** developer runs `make build-app` with a valid mediamtx prebuilt
- **THEN** overlay or install destination contains `bin/mediamtx` that is executable

#### Scenario: Missing prebuilt fails build-app

- **WHEN** mediamtx prebuilt stamp/binary is absent
- **THEN** `make build-app` fails before producing a shippable `/opt/hmi` without the binary

### Requirement: App writes MediaMTX config and supervises the process

The Linux product MediaMTX relay SHALL write YAML to `/run/hmi/mediamtx.yaml` (PR0/PR1 paths, `rtspTransport: udp`, `sourceOnDemand: no`, `logDestinations: [stdout]`) and SHALL start `/opt/hmi/bin/mediamtx` with that config via `package:cyber_pm`, not via `systemctl` or `mediamtx.service`. Identical config content MUST NOT rewrite the file solely to bump mtime. Local fan-out URLs remain `rtsp://127.0.0.1:8554/camera/pr0` and `…/pr1`.

#### Scenario: ensureStarted spawns child

- **WHEN** `IpCameraProductSession` reaches a healthy camera and calls relay ensureStarted
- **THEN** a mediamtx child is running under the App supervisor with the rendered config

#### Scenario: stop ends child

- **WHEN** the product session stops the relay
- **THEN** the mediamtx child is stopped and is not required to remain as a systemd unit

### Requirement: Rootfs no longer ships MediaMTX unit or binary

The product rootfs overlay SHALL NOT ship `/usr/bin/mediamtx`, `mediamtx.service`, or `render-mediamtx-config.sh`. The active `rockchip_rk3566_rk3568_lws_hmi_defconfig` MUST NOT `#include` `chips/lws_hmi_mediamtx.config` as a rootfs packaging gate. `make build-mediamtx` MAY still populate `prebuilt/` for App bundling.

#### Scenario: verify overlay after teardown

- **WHEN** `make apply-overlay` / `verify-rootfs-overlay` runs after this change
- **THEN** checks for `mediamtx.service` wants / render-helper product path are removed or updated so they do not require the deleted unit or script
