# Build optimization

**One command set.** Rootfs scope follows **`overlay/buildroot/rockchip_rk3566_rk3568_lws_hmi_defconfig`**: uncomment `#include` lines as features land in the repo. No `-p1` targets, no stage env var.

---

## How scope is decided

| Layer | What controls it |
|-------|------------------|
| **Which packages** | Active `#include "chips/lws_hmi_*.config"` in defconfig (git) |
| **check-prebuilt** | Only checks deps for those includes |
| **GStreamer / platform** | If `#include` says compile **and** `prebuilt/*/target/` exists → `apply-overlay` swaps to prebuilt overlay automatically |

Example — Hello World today (flutter only):

```makefile
#include "chips/lws_hmi_flutter.config"
# #include "chips/lws_hmi_gst_rtsp.config"    ← enable when P5 video merges
# #include "chips/lws_hmi_platform.config"     ← enable when P2/P5 merges
```

After P5 is merged, uncomment gst/platform in the **same file** — still `make build-rootfs`.

---

## Commands

**Full build** (clean tree or first time):

```bash
make build
```

Runs in order: `check-prebuilt` → `apply-overlay` → `lunch` → `build-boot-logo` →
`build-app` → `build-kernel` → `build-rootfs` → `build-img` → **`output/firmware/update.img` on host** (macOS: auto-export from Docker volume after `build-img` / `build-kernel`).

**Daily iteration** — run only the stage you changed:

```bash
make apply-overlay
make lunch
make check-prebuilt
make build-boot-logo
make build-app
make build-rootfs
make build-kernel
make build-img
make flash
```

Daily:

| Change | Run |
|--------|-----|
| App | `make build-app` → `make build-rootfs` → `make build-img` → `make flash` |
| Kernel / DTS / logo | `make build-kernel` → `make build-img` → `make flash` |
| Defconfig / overlay | `make apply-overlay` → `make build-rootfs` → `make build-img` → `make flash` |

See [`AGENTS.md`](AGENTS.md) for the full path → command mapping for agents.

See [`docs/boot-kpi-optimization.md`](boot-kpi-optimization.md) for boot KPI phased checklist.

---

## Speed tweaks (already in overlay)

- External GCC 10.3 (`lws_hmi_toolchain_external.config`) — skip gcc/glibc compile
- `BR2_JLEVEL=8` + `.env` `BUILD_JOBS=8` (Docker caps `nproc`; no global `MAKEFLAGS` in container — avoids busybox jobserver errors)
- Keep `buildroot/output/` and `buildroot/dl/`

After toolchain or major defconfig change (usually **not** needed when migrating legacy `*_p1` output):

```bash
make migrate-buildroot-output   # reuse lws_hmi_p1 build → lws_hmi
make fix-buildroot-host-rpaths  # if host-cmake/autoreconf fails on stale RUNPATH after rename
make lunch
make build-rootfs
```

Only wipe when intentionally starting over:

```bash
make clean-buildroot-output
make lunch
make build-rootfs
```

---

## Prebuilt runtime (before build-rootfs)

Heavy packages are built **before** rootfs and land in `prebuilt/*/target/`. `build-rootfs` only **consumes** them via overlay (`*_prebuilt.config`), it does not compile gst/platform when export exists.

```bash
make lunch
make build-gstreamer          # BR packages → prebuilt/gstreamer/target/
make build-platform-packages  # → prebuilt/platform-packages/target/
make apply-overlay            # defconfig: *_rtsp → *_prebuilt when export ready
make build-rootfs             # assemble rootfs (no gst/platform recompile)
```

Flutter/mediamtx follow the same rule: `make build-runtime-deps` (or granular `build-flutter-*`) **before** `make build-rootfs`.

`make export-prebuilt` remains a convenience re-export (flutter + runtime); normal flow does not require rootfs first.

---

## Enabling a new feature (workflow)

1. Merge code + uncomment the matching `#include` in `rockchip_rk3566_rk3568_lws_hmi_defconfig`
2. `make apply-overlay` then `make lunch` (if Buildroot profile changed materially: `make clean-buildroot-output` first)
3. `make check-prebuilt` — tells you which `make build-*` / `fetch-*` to run
4. `make build-rootfs`
