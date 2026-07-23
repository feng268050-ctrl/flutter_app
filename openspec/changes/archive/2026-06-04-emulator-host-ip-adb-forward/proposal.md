## Why

LAN clients and companion tools need the **development host's real IPv4** when exercising the app on an Android emulator—for example to reach services the emulator exposes via `adb forward`, or to correlate `deviceInfo` with the machine running `make emulator`. Today the emulator cannot discover the host LAN address automatically, and `model.properties` is only rewritten when `MODEL` is set during a full push path. Separately, `adb forward` for local HTTP (`:5580`) often fails after stale adb server state or when the server binds only to localhost, blocking remote LAN access to the forwarded port.

## What Changes

- **`make emulator`**: Detect the host machine's primary LAN IPv4 (when resolvable) and write `host_ip=<value>` into `/system/etc/model.properties` on the emulator **every run**, without requiring `REBUILD_IMAGE=1` or AVD recreation.
- **`model.properties` push path**: Extend `push_model_properties` (and `.env.example`) to support optional `HOST_IP` env override; auto-detect when unset.
- **Runtime config**: Load `host_ip` from ROM via `DeviceModelConfig`; expose `DeviceModelConfig.getHostIp()` (nullable when absent).
- **Remote snapshot**: Add string field **`hostIp`** to `deviceInfo` in `command.stat_response` / `device.online` (mirroring `cameraIp` semantics)—populated from `DeviceModelConfig.getHostIp()` when present, otherwise empty string or omitted per existing `cameraIp` empty handling.
- **adb forward prelude**: Before `adb forward tcp:5580` in `make emulator`, `make install` (emulator target), `make emulator-forward`, and shared helpers—run `adb kill-server` then `adb -a server start` so adb listens on `0.0.0.0` and forward mappings are reachable from other machines on the LAN.

## Capabilities

### New Capabilities

<!-- None — behavior extends existing tooling and snapshot specs -->

### Modified Capabilities

- `device-remote-snapshot`: `deviceInfo` includes `hostIp` sourced from ROM `host_ip` when configured.
- `build-ci-tooling`: Document and require emulator workflow updates—host IP injection on every `make emulator`, and adb server restart (`kill-server` + `adb -a server start`) before emulator `:5580` forward setup.

## Impact

- **Scripts**: `scripts/emulator-system-common.sh` (`push_model_properties`, `setup_emulator_local_http_forward`), `scripts/emulator-launch.sh`, `scripts/emulator-forward-local-http.sh`, `scripts/ci/maybe-emulator-forward-local-http.sh`, `Makefile` help text.
- **App**: `DeviceModelConfig`, `DeviceInfo`, `DeviceStatusPut`, unit tests (`DeviceRemoteSnapshotTest`).
- **Docs**: `docs/network-api-reference.md`, `.env.example`.
- **API surface**: Non-breaking additive JSON field `deviceInfo.hostIp` on WebSocket stat payloads and cloud stat when Worker forwards the snapshot.
