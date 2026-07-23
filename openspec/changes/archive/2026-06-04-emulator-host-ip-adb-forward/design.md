## Context

The LWS emulator workflow (`make emulator` → `scripts/emulator-launch.sh`) boots a writable-system AVD, remounts `/system`, pushes privapp permissions, and optionally writes `/system/etc/model.properties` when `MODEL` is set. `camera_ip` is already injected via `push_model_properties` and read at runtime by `DeviceModelConfig`, then surfaced as `deviceInfo.cameraIp` in the remote snapshot (`DeviceStatusPut`).

Companion tools on the LAN cannot infer the dev host's IPv4 from inside the emulator. Operators already use `adb forward tcp:5580` so phones or other machines can hit `DeviceLocalHttpServer`, but the adb server defaults to localhost-only binding and stale server state causes flaky forwards.

## Goals / Non-Goals

**Goals:**

- On every successful `make emulator` boot + remount, update `/system/etc/model.properties` with `host_ip=<detected-or-env>` when a host LAN IPv4 is available.
- Allow optional `HOST_IP` env / `.env` override (same pattern as `CAMERA_IP`).
- Load `host_ip` in-app via `DeviceModelConfig.getHostIp()` and expose `deviceInfo.hostIp` in `command.stat_response` / `device.online` snapshots (non-Room transient field, parallel to `cameraIp`).
- Before any emulator `:5580` forward setup (`make emulator`, `make install` emulator path, `make emulator-forward`), restart adb as `adb kill-server` then `adb -a server start`.

**Non-Goals:**

- Auto-detect host IP at runtime inside the APK on production hardware (only ROM injection for emulator/dev).
- Change `10.0.2.2` emulator NAT semantics or require bridged networking.
- Persist `hostIp` in Room or Settings UI.
- Restart adb server on physical-device `make install` / CI device flows (emulator serial prefix `emulator-*` only).

## Decisions

### 1. `model.properties` key name: `host_ip`

Follow existing snake_case ROM keys (`camera_ip`, `model`, `sn`). Env override variable: `HOST_IP` (documented in `.env.example`).

### 2. Always sync `model.properties` on emulator, not only when `MODEL` is set

**Decision:** Replace the `if [[ -n "${MODEL}" ]]` gate with a `sync_model_properties` helper that runs after every emulator remount.

**Merge strategy:**

1. Build desired properties in a temp file on the host.
2. If the device already has `/system/etc/model.properties`, `adb pull` it first and preserve keys not being updated.
3. Apply overrides in order: existing file → env `MODEL`/`SN`/`CAMERA_IP`/`HOST_IP` (non-empty env wins).
4. Resolve host IP when `HOST_IP` unset: shell helper `resolve_host_lan_ipv4()` using OS-specific default-route interface lookup (macOS: `route -n get default` + `ipconfig getifaddr`; Linux: `ip -4 route get 1.1.1.1` / `hostname -I`). Skip `host_ip` line when detection fails.
5. `adb push` merged file, chmod/chown/restorecon as today.

**Rationale:** Satisfies "every `make emulator` updates without `REBUILD_IMAGE=1`" while keeping prior `model`/`sn`/`camera_ip` on AVD reuse.

**Alternative rejected:** Require `REBUILD_IMAGE=1` or `MODEL` set — fails the stated requirement.

### 3. Runtime read path mirrors `camera_ip`

Add `DeviceModelConfig.getHostIp()` returning `null` when key absent. `DeviceStatusPut` sets `deviceInfo.setHostIp(...)` using empty string when null (Gson emits `"hostIp":""`, consistent with default `cameraIp` field).

**Alternative rejected:** Hardcode in `BuildConfig` — would not update per emulator session without rebuild.

### 4. Centralize adb restart in `setup_emulator_local_http_forward`

Add `ensure_adb_server_listen_all_interfaces()`:

```bash
adb kill-server 2>/dev/null || true
adb -a server start
```

Call at the beginning of `setup_emulator_local_http_forward` (shared by emulator launch, install tail, `emulator-forward`). Use the same SDK-resolved `adb` binary already resolved in that function.

**Rationale:** Single choke point; all forward entry paths already funnel here.

**Alternative rejected:** Only document manual `adb -a` — does not fix flaky automation.

### 5. App cache invalidation

`DeviceModelConfig` loads once per process. After `model.properties` push, the running app (if any) won't see new `host_ip` until restart. `try_start_app` runs after sync — acceptable; document that re-launch may be needed if app was already running before sync.

## Risks / Trade-offs

- **[Host IP detection ambiguity on multi-homed machines]** → Prefer default-route interface; allow `HOST_IP` override in `.env`.
- **[VPN / Docker interfaces]** → Detection may return VPN address; operators can set `HOST_IP` explicitly.
- **[adb -a exposes adb on LAN]** → Dev-only emulator workflow; document security note in Makefile help / network docs.
- **[sync without MODEL on fresh AVD]** → File may contain only `host_ip`; app falls back to default model from `DeviceModelConfig` when `model` key missing — unchanged behavior.
- **[Running app stale hostIp until restart]** → Sync runs before `try_start_app`; reboot after `make install` reloads config.

## Migration Plan

1. Land script + app changes together.
2. Developers re-run `make emulator` (no AVD recreate required) to pick up `host_ip`.
3. Cloud/consumers: treat `deviceInfo.hostIp` as optional additive field; no breaking change.

## Open Questions

- None — empty `hostIp` when ROM key absent matches `cameraIp` empty-default pattern.
