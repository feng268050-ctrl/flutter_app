# Inventory (task 1.1) — 2026-07-22

## ICMP / HAL health

- `IpCameraProbe` = `Future<bool> Function(String cameraHost)` in `packages/cyber_hal/lib/src/ip_camera/ip_camera_models.dart`
- Default: `LinuxIpCameraController` → `_defaultIcmpProbe` (`ping -c 1 -W 1` on Linux)
- Injection: ctor `probe:`; timer 1s; debounce recovery/failure 3; `suspendProbes` / `resumeProbes` + 5s quiet
- Eth0 configure has a separate one-shot ping (`LinuxIpCameraEth0Path`) → `configurePingOk` seed only

## MediaMTX / path signals (no PR0/PR1 open)

| Signal | Meaning | Usable for health? |
|--------|---------|-------------------|
| `path.ok` / session `_pathReady` | eth0 L3 applied | Path only |
| `path.pingOk` | configure-time ICMP | Host ICMP, not continuous |
| `relayStatus.phase == running` | `systemctl is-active mediamtx` | **Unit up ≠ upstream OK** |
| `previewReady` | UI connected + relay running | Preview selection |

**Gap:** No MediaMTX HTTP API / path-ready / upstream-track signal in product code today. Rung 1 can at best compose path + unit + a light host probe — not true “MediaMTX still holding PR0.”

## Composition site

`AppServices.ensureIpCamera` → `IpCameraProductSession.create` builds `LinuxIpCameraController(cameraHost:)` with **no custom probe** (ICMP default).

## TCP / OPTIONS

None yet — added in task 1.2.
