## Context

Default image stamp is `/etc/display-stack=weston`: `hmi-launch.sh` starts Weston (desktop-shell) then `flutter-wayland-client --bundle=/opt/hmi --fullscreen`, which loads AOT via `lib/libapp.so`. Alternate image is `flutter-pi` with DRM/GBM.

P1.5 `make debug-app` builds a JIT bundle (`kernel_blob.bin` + snapshots) via `flutterpi_tool`, caches debug `libflutter_engine.so` under `/var/lib/hmi/debug-runtime/<ver>/`, sets `/opt/hmi/runtime-mode.json` to `mode=debug`, and launches via `debug-app-run` → `hmi-launch`. Only the **flutter-pi** branch of `hmi-launch` understands debug (LD_LIBRARY_PATH + no `--release`). The Weston branch currently requires `libapp.so` and rejects `mode=debug`.

Sony flutter-embedded-linux documents switching debug/profile/release by pointing `LD_LIBRARY_PATH` at the matching engine; `FlutterEngineRunsAOTCompiledDartCode()` selects AOT vs JIT. `DartProject` always *names* `lib/libapp.so` but does not require the file for non-AOT engines. Debug assets already include `vm_snapshot_data` / `isolate_snapshot_data` / `kernel_blob.bin`. eLinux expects ICU at `<bundle>/data/icudtl.dat` (unlike flutter-pi’s `FLUTTER_EMBEDDER_ICU_DATA_PATH`).

A temporary host guard refuses Weston deploy to avoid blanking panels; this change replaces that with a real Weston debug path.

## Goals / Non-Goals

**Goals:**

- `make debug-app` and the IDE custom-device path work on default Weston boards (USB-SSH or registered SSH).
- Preserve flutter-pi debug and both stacks’ release `push-app` behavior.
- Fail before stopping the running HMI when debug runtime or JIT assets are missing/incompatible.
- Document the unified workflow in `app/README.md`.

**Non-Goals:**

- Rebuilding `flutter-wayland-client` as a separate debug binary.
- Profile-mode productization (may work incidentally; not required).
- Changing Flutter SDK pin, engine version, or Mali/Weston packaging.
- Emulator / Android debug paths.
- Removing the alternate flutter-pi rootfs.

## Decisions

### 1. Reuse existing debug payload + runtime cache

**Choice:** Same staging layout as today (`kernel_blob` under `/opt/hmi/data/flutter_assets/`, engine under `/var/lib/hmi/debug-runtime/<ver>/`, `runtime-mode.json` with `mode` + `engine_version`). Do not introduce a second Weston-specific debug format.

**Why:** Host deploy/IDE adapters already work; eLinux consumes the same Flutter embedder asset layout. Alternatives (flutter-elinux CLI on host, separate AOT “debug” without JIT) would fork tooling or lose hot reload.

### 2. Weston debug launch = `LD_LIBRARY_PATH` + existing client

**Choice:** In `hmi-launch` Weston branch, when `mode=debug` and `/var/lib/hmi/debug-runtime/<ver>/{libflutter_engine.so,icudtl.dat}` exist: ensure `/opt/hmi/data/icudtl.dat`, require `kernel_blob.bin`, start Weston as today, then:

`env LD_LIBRARY_PATH=<runtime> "$ELINUX_CLIENT" --bundle=/opt/hmi --fullscreen`

**Why:** Matches Sony’s documented pattern; avoids rebuilding the client. Alternative (link a debug client into rootfs) adds image size and dual packaging.

### 3. Host deploy is display-stack-aware, not Weston-blocked

**Choice:** Remove the hard refuse of `display-stack=weston`. Optionally log which stack was detected. Still refuse unknown/broken stacks if needed. Board `debug-app-apply` may keep a soft check that JIT assets exist, but MUST NOT refuse Weston.

**Why:** Default image is Weston; blocking it defeats the change. Failures belong in missing-runtime / missing-kernel checks before apply.

### 4. Fail closed before apply when prerequisites missing

**Choice:** Host (and/or apply) verifies debug runtime cache target path and `kernel_blob.bin` before `hmi-stop`. Weston-specific: after apply, launch must not leave a half-installed AOT-less tree without a recoverable path — apply remains atomic as today; if launch fails, `push-app` restores release.

**Why:** Spec already requires fail-before-stop for incompatible engines; extend the spirit to stack launch readiness (ICU copy can happen at launch from cached runtime).

### 5. VM Service / IDE path unchanged

**Choice:** Keep `debug-app-run.sh` waiting on the same “VM Service / Observatory listening” log lines and custom-device port forward. No new IDE device id.

**Why:** Engine debug builds emit the same messages; tunnel already works for flutter-pi.

## Risks / Trade-offs

- **[Risk] Release client + debug engine ABI mismatch** → Mitigation: same pinned Flutter 3.24.4 engine source for release and debug (existing contract); board smoke before landing; if `dlopen` fails, surface engine path in log and keep fail-before-stop where possible.
- **[Risk] Missing `icudtl.dat` under bundle `data/`** → Mitigation: launch copies from debug-runtime (and/or apply installs it); mirror existing Weston release ICU fallback.
- **[Risk] JIT memory / startup slower on RK3566** → Mitigation: accept for debug-only; document; release path unchanged.
- **[Risk] Plugin native `.so` assuming release engine** → Mitigation: HMI plugins used on device are already exercised under Weston release; debug session smoke includes Settings/video if practical.
- **[Trade-off] One client binary for all modes** → Simpler images; relies on dynamic engine load (Sony-supported).

## Migration Plan

1. Land host + overlay script changes; developers get Weston debug after `apply-overlay` + `build-rootfs` + `upgrade` (or push overlay scripts for faster iteration if policy allows).
2. Host-only pieces (`debug-app-deploy` guard removal) apply immediately; full launch needs updated `hmi-launch` on board.
3. Rollback: restore previous scripts / re-flash; `make push-app` restores release AOT on a board stuck on debug payload.
4. Docs: update `app/README.md` P1.5 section.

## Open Questions

- None blocking: board validation of `LD_LIBRARY_PATH` with the shipped `flutter-wayland-client` is the first implementation spike task; if it fails, escalate to packaging a debug-capable client (out of current non-goals until proven necessary).
