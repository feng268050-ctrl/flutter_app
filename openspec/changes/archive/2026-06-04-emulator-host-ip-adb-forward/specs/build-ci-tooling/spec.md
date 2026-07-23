## ADDED Requirements

### Requirement: make emulator syncs host LAN IP into model.properties every run

The `make emulator` workflow (via `scripts/emulator-launch.sh` and shared helpers) SHALL, after successful adb remount on the target emulator, update `/system/etc/model.properties` on the guest **on every invocation**, without requiring `REBUILD_IMAGE=1` or AVD recreation.

When a host LAN IPv4 can be resolved, the sync SHALL write property `host_ip=<ipv4>`. When resolution fails and env `HOST_IP` is unset or empty, the sync MUST NOT add or overwrite `host_ip` with a placeholder. When env `HOST_IP` is set to a non-empty value, that value MUST be written as `host_ip`.

The sync MUST preserve existing keys in the on-device file (e.g. `model`, `sn`, `camera_ip`) unless overridden by corresponding env vars (`MODEL`, `SN`, `CAMERA_IP`) or explicit merge rules documented in the emulator scripts.

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

### Requirement: Emulator local HTTP forward restarts adb server on all interfaces

Before establishing `adb forward tcp:5580 tcp:5580` for an emulator serial (`emulator-*`), automation SHALL execute `adb kill-server` followed by `adb -a server start` using the same SDK `adb` binary used for the forward.

This prelude MUST run in the shared forward helper invoked by `make emulator`, `make install` when the adb target is an emulator, and `make emulator-forward`.

#### Scenario: Emulator launch forward uses adb -a

- **WHEN** `make emulator` completes boot and remount and sets up local HTTP forward
- **THEN** automation MUST restart the adb server with `-a` before creating the `tcp:5580` forward mapping

#### Scenario: make install on emulator restarts adb before forward

- **WHEN** `make install` targets serial `emulator-5554` and re-applies the `:5580` forward after reboot
- **THEN** automation MUST run `adb kill-server` and `adb -a server start` before forward setup

#### Scenario: Physical device install does not require adb -a prelude

- **WHEN** `make install` targets a non-emulator adb serial
- **THEN** the adb `-a` restart prelude for emulator forward MUST NOT be required for that install path
