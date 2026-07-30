## Context

Today MediaMTX is staged into the rootfs overlay (`/usr/bin/mediamtx`), started on demand via `mediamtx.service` + `systemctl` from `LinuxIpCameraMediaMtxRelay`, with YAML rendered by `/usr/libexec/hmi/render-mediamtx-config.sh`. That couples a ~44 MiB IPC-only binary to the shared OS image. AI will need the same App-owned child-process pattern. Platform packages already use the `cyber_*` naming for reusable HMI libraries.

## Goals / Non-Goals

**Goals:**
- Move MediaMTX binary and lifecycle into the product App tree (`/opt/hmi`).
- Provide reusable `packages/cyber_pm` for spawn / stop / restart / log drain.
- Keep preview URLs `rtsp://127.0.0.1:8554/camera/pr{0,1}` and product session orchestration unchanged at the API level.

**Non-Goals:**
- AI daemon binary or Unix-socket protocol.
- Moving GStreamer / MPP out of rootfs.
- Non-root HMI / polkit for child spawn.
- Putting the MediaMTX ELF into Flutter `assets/`.

## Decisions

1. **`cyber_pm` path package (not cyber_hal, not App-private)**  
   HAL is board I/O; process supervision is a generic runtime concern shared by MediaMTX, future AI, and other product Apps. Pure Dart + `dart:io`; injectable `Process` factory for tests.

2. **Binary at `/opt/hmi/bin/mediamtx` via build-app**  
   Copied from `prebuilt/mediamtx/linux-arm64/` during bundle install. Survives `push-app`. Avoids Flutter asset packaging for a large executable.

3. **Dart config → `/run/hmi/mediamtx.yaml`**  
   Same path semantics as the shell renderer (PR0/PR1, udp, `sourceOnDemand: no`, skip rewrite when content unchanged). tmpfs is fine for ephemeral config; regenerate on each ensure.

4. **RestartPolicy onFailure ~3s** for MediaMTX  
   Matches old unit `Restart=on-failure` / `RestartSec=3`. AI can pass a different policy later.

5. **Log drain → print with stable prefix**  
   Under `hmi.service` `StandardOutput=journal`, operators use `make logs GREP=mediamtx`.

6. **Rootfs teardown**  
   Delete unit, overlay binary sync, render script; remove defconfig include; move mediamtx stamp gate to build-app.

## Risks / Trade-offs

- **[Risk] Leftover `/usr/bin/mediamtx` on boards until rebuild-rootfs** → App prefers `/opt/hmi/bin/mediamtx`; next rootfs drops old path. Document rebuild.
- **[Risk] Child dies with HMI; no systemd Restart across App crash** → Supervisor onFailure covers child crash while App lives; HMI `Restart=on-failure` restarts App which re-runs session.
- **[Risk] Port 8554 held by orphan** → `stop()` / dispose kill; ensureStarted avoids double-spawn; onFailure respawn after exit.
- **[Trade-off] ~44 MiB on every `push-app`** → Acceptable vs baking into every product rootfs.

## Migration Plan

1. Land `cyber_pm` + App relay + bundle copy.
2. `make build-app` + `make push-app` for functional cutover on existing boards (rootfs may still contain old binary unused).
3. `make apply-overlay` + `make build-rootfs` + `make upgrade` to purge overlay artifacts.
4. Rollback: revert App to systemctl path only if unit still present (post-rootfs teardown, rollback needs App revert + reintroduce overlay — prefer forward fix).

## Open Questions

None — decisions locked in the implementation plan.
