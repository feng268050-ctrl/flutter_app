## ADDED Requirements

### Requirement: make prepare writes focus_scale_ref to model.properties

The `make prepare` workflow (via `scripts/ci/prepare-device.sh`) SHALL support env var **`FOCUS_SCALE_REF`** as a signed integer. When model config is written to `/system/etc/model.properties`, the script MUST include `focus_scale_ref=<value>`.

When `FOCUS_SCALE_REF` is unset and the script writes model config keys, `focus_scale_ref` MUST default to `0`.

When `FOCUS_SCALE_REF` is set to a non-integer value, the script MUST fail with a non-zero exit and a clear error message.

The prepare script MUST write model config when **only** `FOCUS_SCALE_REF` is set (alongside existing triggers for `MODEL`, `SN`, `CAMERA_IP`, `CAMERA_TYPE`).

#### Scenario: Prepare with explicit focus scale ref

- **WHEN** the developer runs `FOCUS_SCALE_REF=5 make prepare` with other required env set
- **THEN** `/system/etc/model.properties` on the device MUST contain `focus_scale_ref=5`

#### Scenario: Prepare without FOCUS_SCALE_REF defaults to zero

- **WHEN** the developer runs `make prepare` with `MODEL` or `SN` set but `FOCUS_SCALE_REF` unset
- **THEN** the pushed `model.properties` MUST contain `focus_scale_ref=0`

#### Scenario: Prepare with negative focus scale ref

- **WHEN** the developer runs `FOCUS_SCALE_REF=-3 make prepare`
- **THEN** `/system/etc/model.properties` MUST contain `focus_scale_ref=-3`

#### Scenario: Invalid FOCUS_SCALE_REF rejected

- **WHEN** the developer runs `FOCUS_SCALE_REF=abc make prepare`
- **THEN** prepare MUST exit non-zero before modifying the device

### Requirement: Makefile documents FOCUS_SCALE_REF for prepare and emulator

The root `Makefile` help text SHALL document `FOCUS_SCALE_REF=<int>` for `make prepare` and `make emulator`, noting default `0`.

#### Scenario: make help lists focus scale ref

- **WHEN** the developer runs `make help` (or equivalent documented help target)
- **THEN** output MUST mention `FOCUS_SCALE_REF` alongside other `model.properties` env vars

## MODIFIED Requirements

### Requirement: make emulator syncs host LAN IP into model.properties every run

The `make emulator` workflow (via `scripts/emulator-launch.sh` and shared helpers) SHALL, after successful adb remount on the target emulator, update `/system/etc/model.properties` on the guest **on every invocation**, without requiring `REBUILD_IMAGE=1` or AVD recreation.

When a host LAN IPv4 can be resolved, the sync SHALL write property `host_ip=<ipv4>`. When resolution fails and env `HOST_IP` is unset or empty, the sync MUST NOT add or overwrite `host_ip` with a placeholder. When env `HOST_IP` is set to a non-empty value, that value MUST be written as `host_ip`.

The sync MUST preserve existing keys in the on-device file (e.g. `model`, `sn`, `camera_ip`, `camera_type`, `focus_scale_ref`) unless overridden by corresponding env vars (`MODEL`, `SN`, `CAMERA_IP`, `CAMERA_TYPE`, `FOCUS_SCALE_REF`) or explicit merge rules documented in the emulator scripts.

Env **`CAMERA_TYPE`** SHALL accept `1` or `2`. When set, the sync MUST write `camera_type=<value>`. When unset, the sync MUST retain an existing on-device `camera_type` if present; otherwise MUST write `camera_type=1`. Invalid `CAMERA_TYPE` values MUST cause the emulator workflow to fail before push.

Env **`FOCUS_SCALE_REF`** SHALL accept a signed integer. When set, the sync MUST write `focus_scale_ref=<value>`. When unset, the sync MUST retain an existing on-device `focus_scale_ref` if present; otherwise MUST write `focus_scale_ref=0`. Invalid `FOCUS_SCALE_REF` values MUST cause the emulator workflow to fail before push.

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

#### Scenario: FOCUS_SCALE_REF written on emulator launch

- **WHEN** the developer runs `FOCUS_SCALE_REF=-4 make emulator`
- **THEN** `/system/etc/model.properties` on the emulator MUST contain `focus_scale_ref=-4` after sync completes

#### Scenario: Emulator defaults focus_scale_ref when unset

- **WHEN** the developer runs `make emulator` without `FOCUS_SCALE_REF`
- **AND** the on-device file has no `focus_scale_ref` key
- **THEN** the synced file MUST contain `focus_scale_ref=0`
