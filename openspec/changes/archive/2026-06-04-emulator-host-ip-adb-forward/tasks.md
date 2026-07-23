## 1. Emulator scripts — host IP + model.properties sync

- [x] 1.1 Add `resolve_host_lan_ipv4()` in `scripts/emulator-system-common.sh` (macOS + Linux default-route detection; return empty on failure)
- [x] 1.2 Refactor `push_model_properties` → `sync_model_properties`: pull-merge-push `/system/etc/model.properties`; preserve existing keys; apply `MODEL`/`SN`/`CAMERA_IP`/`HOST_IP` env overrides when set
- [x] 1.3 When `HOST_IP` unset, call `resolve_host_lan_ipv4()` and write `host_ip=` only when non-empty
- [x] 1.4 In `scripts/emulator-launch.sh`, call `sync_model_properties` after remount on every run (remove `MODEL`-only gate)
- [x] 1.5 Source `HOST_IP` from `.env` in `emulator-system-common.sh` (same pre-set pattern as `CAMERA_IP` / `MODEL`)
- [x] 1.6 Update `scripts/emulator-launch.sh` header comments to document always-on sync and `host_ip`

## 2. Emulator scripts — adb server restart before forward

- [x] 2.1 Add `ensure_adb_server_listen_all_interfaces(adb_bin)` in `scripts/emulator-system-common.sh` (`adb kill-server` then `adb -a server start`)
- [x] 2.2 Call it at the start of `setup_emulator_local_http_forward` before `adb forward tcp:5580`
- [x] 2.3 Verify `scripts/emulator-forward-local-http.sh` and `scripts/ci/maybe-emulator-forward-local-http.sh` inherit the prelude via shared helper (no duplicate logic)

## 3. App runtime — load and expose hostIp

- [x] 3.1 Add `HOST_IP_KEY` / `getHostIp()` to `DeviceModelConfig` (nullable when absent)
- [x] 3.2 Add transient `hostIp` field to `DeviceInfo` (mirror `cameraIp` `@Ignore` pattern)
- [x] 3.3 In `DeviceStatusPut`, set `deviceInfo.setHostIp(...)` from `DeviceModelConfig.getHostIp()` (empty string when null)

## 4. Tests and docs

- [x] 4.1 Extend `DeviceRemoteSnapshotTest` with Gson serialization test for `hostIp`
- [x] 4.2 Add shell unit test or documented manual check for `resolve_host_lan_ipv4` if feasible (optional smoke in script `--help` / comment)
- [x] 4.3 Update `.env.example` with `HOST_IP` comment
- [x] 4.4 Update `docs/network-api-reference.md` — `deviceInfo.hostIp` field and emulator `host_ip` injection note
- [x] 4.5 Update `Makefile` help for `HOST_IP` and adb `-a` behavior on emulator forward targets

## 5. Verification

- [x] 5.1 Run `make emulator` (or dry-run script path): confirm `/system/etc/model.properties` contains `host_ip` when detectable, without `REBUILD_IMAGE=1`
- [x] 5.2 Confirm `command.stat_response` JSON includes `deviceInfo.hostIp` matching ROM value after app restart
- [x] 5.3 Confirm `adb -a server start` runs before forward; LAN client can reach `http://<host-ip>:5580/` when firewall allows
