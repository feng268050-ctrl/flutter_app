## ADDED Requirements

### Requirement: Whole-device make upgrade remains OS-scoped

`make upgrade` SHALL continue to package/serve/apply the **whole-device** OTA archive (boot/rootfs/optional oem) and MUST NOT be redefined as an app-only install path. App-only remote updates SHALL use **`make upgrade-app`**. Device selection and host HTTP control-plane conventions MAY remain shared with `upgrade-app`, but the payload and on-device apply pipeline remain A/B partition OTA.

#### Scenario: make upgrade does not install app tar.gz only

- **WHEN** the operator runs `make upgrade` for a normal (non-`OEM_ONLY`) session
- **THEN** the served package is the whole-device OTA archive (or documented OEM-only subset)
- **AND** MUST NOT treat an app-only `lws-hmi/app` `tar.gz` as a substitute for rootfs/boot OTA

#### Scenario: Operators use upgrade-app for app-only

- **WHEN** the operator wants to update only `/opt/hmi` over SSH/HTTP
- **THEN** the documented Make target is `make upgrade-app`, not `make upgrade`
