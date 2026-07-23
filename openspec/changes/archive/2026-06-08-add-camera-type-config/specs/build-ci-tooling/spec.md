## ADDED Requirements

### Requirement: make prepare writes camera_type to model.properties

The `make prepare` workflow (via `scripts/ci/prepare-device.sh`) SHALL support env var **`CAMERA_TYPE`** with allowed values `1` or `2`. When model config is written to `/system/etc/model.properties`, the script MUST include `camera_type=<value>`.

When `CAMERA_TYPE` is unset and the script writes model config keys, `camera_type` MUST default to `1`.

When `CAMERA_TYPE` is set to a value other than `1` or `2`, the script MUST fail with a non-zero exit and a clear error message.

#### Scenario: Prepare with explicit red light

- **WHEN** the developer runs `CAMERA_TYPE=2 make prepare` with other required env set
- **THEN** `/system/etc/model.properties` on the device MUST contain `camera_type=2`

#### Scenario: Prepare without CAMERA_TYPE defaults to one

- **WHEN** the developer runs `make prepare` with `MODEL` or `SN` set but `CAMERA_TYPE` unset
- **THEN** the pushed `model.properties` MUST contain `camera_type=1`

#### Scenario: Invalid CAMERA_TYPE rejected

- **WHEN** the developer runs `CAMERA_TYPE=3 make prepare`
- **THEN** prepare MUST exit non-zero before modifying the device

### Requirement: Makefile documents CAMERA_TYPE for prepare and emulator

The root `Makefile` help text SHALL document `CAMERA_TYPE=<1|2>` for `make prepare` and `make emulator`, noting default `1` (BLUE_LIGHT) and `2` (RED_LIGHT).

#### Scenario: make help lists camera type

- **WHEN** the developer runs `make help` (or equivalent documented help target)
- **THEN** output MUST mention `CAMERA_TYPE` alongside `CAMERA_IP` and `HOST_IP`

## MODIFIED Requirements

### Requirement: make emulator syncs host LAN IP into model.properties every run

The `make emulator` workflow (via `scripts/emulator-launch.sh` and shared helpers) SHALL, after successful adb remount on the target emulator, update `/system/etc/model.properties` on the guest **on every invocation**, without requiring `REBUILD_IMAGE=1` or AVD recreation.

When a host LAN IPv4 can be resolved, the sync SHALL write property `host_ip=<ipv4>`. When resolution fails and env `HOST_IP` is unset or empty, the sync MUST NOT add or overwrite `host_ip` with a placeholder. When env `HOST_IP` is set to a non-empty value, that value MUST be written as `host_ip`.

The sync MUST preserve existing keys in the on-device file (e.g. `model`, `sn`, `camera_ip`, `camera_type`) unless overridden by corresponding env vars (`MODEL`, `SN`, `CAMERA_IP`, `CAMERA_TYPE`) or explicit merge rules documented in the emulator scripts.

Env **`CAMERA_TYPE`** SHALL accept `1` or `2`. When set, the sync MUST write `camera_type=<value>`. When unset, the sync MUST retain an existing on-device `camera_type` if present; otherwise MUST write `camera_type=1`. Invalid `CAMERA_TYPE` values MUST cause the emulator workflow to fail before push.

#### Scenario: Host IP detected on emulator launch

- **WHEN** the developer runs `make emulator` and the host resolves LAN IPv4 `192.168.1.50`
- **THEN** `/system/etc/model.properties` on the emulator MUST contain `host_ip=192.168.1.50` after remount completes

#### Scenario: Reused AVD without REBUILD_IMAGE still updates host_ip

- **WHEN** the developer runs `make emulator` on an existing AVD without `REBUILD_IMAGE=1`
- **AND** the host LAN IPv4 changes or is newly detectable
- **THEN** the on-device `host_ip` property MUST reflect the current detected value after that run

#### Scenario: HOST_IP env override wins over auto-detect

- **WHEN** the developer runs `make emulator` with `HOST_IP=10.0.0.8` set
- **THEN** `/system/etc/model.properties` MUST contain `host_ip=10.0.0.8` regardless of auto-detected addresses

#### Scenario: CAMERA_TYPE written on emulator launch

- **WHEN** the developer runs `CAMERA_TYPE=2 make emulator`
- **THEN** `/system/etc/model.properties` on the emulator MUST contain `camera_type=2` after sync completes

#### Scenario: Emulator defaults camera_type when unset

- **WHEN** the developer runs `make emulator` without `CAMERA_TYPE`
- **AND** the on-device file has no `camera_type` key
- **THEN** the synced file MUST contain `camera_type=1`
