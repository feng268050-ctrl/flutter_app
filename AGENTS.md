# AGENTS.md

Instructions for coding agents working in **lws-hmi**. Human-oriented overview and long command lists live in [`README.md`](README.md); this file adds agent-specific rules agents should follow automatically.

## Project overview

- **What:** Buildroot firmware for Innohi **ynh960/961/962 product line** + Flutter-pi HMI (`app/hmi/`).
- **Board SKUs:** ynh960 → RK3566 (entry); ynh962 → RK3568B2 (mid, cut-down 3568); ynh961 → RK3568 (high). Same product line (minor chip/interface differences); **one firmware image is the goal**. **P1–P5 develop and validate on ynh960 (RK3566)** — no per-SKU defconfig fork yet.
- **Hosts:** Linux builds natively in `linux-sdk/`; macOS uses Docker `linux/amd64` + a Docker volume for the SDK tree.
- **Outputs:** `output/firmware/update.img` (macOS, after export); Linux also `linux-sdk/output/firmware/`.
- **Scope:** Active Buildroot packages follow `#include` lines in `overlay/buildroot/rockchip_rk3566_rk3568_lws_hmi_defconfig`.

## Dev environment tips

- Run `make help` for the authoritative Makefile target list.
- First time: `make setup`, then `make build-deps`, then `make build` (macOS: `make docker-volume-init` before build).
- The Rockchip SDK is fixed at repo-root `linux-sdk/`; override the Flutter SDK via repo-root `.env` or `FLUTTER_SDK` (default: `flutter-sdk/`). Other common settings are `BUILD_JOBS` and `SERIAL`.
- macOS: prefer Docker volume over `BUILD_BIND_MOUNT=1` (bind-mount often crashes Docker Desktop during Buildroot).
- Flutter app work: host needs `flutter` + `flutterpi_tool` (`make fetch-flutter-sdk` / `make build-dev-deps`).
- Do not commit unless the user explicitly asks.

## Build commands

Full cookbook: **README.md → Make commands**. Quick reference:

```bash
make build
make show-config
```

First-time dependencies:

```bash
make build-deps
make check-prebuilt
```

Daily iteration examples (one command per line; run in order):

```bash
# Flutter app (app/hmi/)
make build-app
make build-rootfs
make build-img
make flash

# Kernel / DTS / boot logo
make build-boot-logo
make build-kernel
make build-img
make flash

# Overlay / systemd / LCD params (not app bundle)
make apply-overlay
make build-rootfs
make build-img
make flash
```

More detail: [`docs/build-optimization.md`](docs/build-optimization.md), [`app/README.md`](app/README.md).

**Pipeline rules (do not get wrong):**

- `make build-app` updates overlay `/opt/hmi` and runs `apply-overlay`; it does **not** rebuild rootfs.
- `make build-rootfs` bakes fs-overlay (including `/opt/hmi`) into rootfs.
- `make build-img` only repacks from existing kernel + rootfs outputs.

## Rebuild instructions for the user (required)

After **any non-docs code change**, end your reply with a **「重新构建」** block. The user does not know which paths you touched — list exact `make` lines, **one per line**, in order. Omit `make flash` if they build on Linux and flash elsewhere.

| What changed | Commands |
|--------------|----------|
| `app/hmi/**`, `scripts/build-app.sh` | `make build-app`, `make build-rootfs`, `make build-img`, `make flash` |
| `board/logo/**` | `make build-boot-logo`, `make build-kernel`, `make build-img`, `make flash` |
| `overlay/kernel/**`, kernel DTS | `make apply-overlay`, `make build-kernel`, `make build-img`, `make flash` |
| `overlay/.../lws-hmi-fs-overlay/**` (not app) | `make apply-overlay`, `make build-rootfs`, `make build-img`, `make flash` |
| USB plug-ssh (`overlay/kernel/**` + fs-overlay scripts/units) | `make apply-overlay`, `make build-kernel`, `make build-rootfs`, `make build-img`, `make flash` |
| `scripts/push-app.sh` only (app already on device) | `make build-app`, `make push-app` |
| `scripts/device-logs.sh` only (host log streaming) | none |
| `scripts/debug-app*.sh`, `scripts/debug-custom-device/**`, `scripts/debug-setup.sh`, `scripts/build-debug-app.sh` (host only; board already has P1.5 overlay) | `make debug-setup`, `make debug-app` |
| `overlay/.../lws-hmi-fs-overlay/**` debug scripts (`hmi-launch.sh`, `debug-app-*`, `hmi.service`) | `make apply-overlay`, `make build-rootfs`, `make build-img`, `make flash` |
| `overlay/buildroot/**` | `make apply-overlay`, `make check-prebuilt`, `make build-rootfs`, `make build-img`, `make flash` |
| `prebuilt/**`, runtime recipes | `make build-runtime-deps` (or specific target), `make apply-overlay`, `make build-rootfs`, `make build-img`, `make flash` |
| `board/*.txt` LCD/MIPI params | `make apply-overlay`, `make build-rootfs`, `make build-img`, `make flash` |
| `board/parameter-buildroot-fit.txt` (GPT) | `make apply-overlay`, `make build-img`, `make flash` |
| `fetch-*`, `build-dev-deps` only | no firmware rebuild; name the fetch/build-deps target |
| Docs only | none |

Example:

```text
重新构建（本次改动了 app）：
make build-app
make build-rootfs
make build-img
make flash
```

When unsure or on a clean tree: `make build`.

## Code conventions

- **Minimize scope** — smallest correct diff; no drive-by refactors.
- **Match existing style** in touched files (shell, Dart, Buildroot `.mk`, overlay layout).
- **Paths:** app → `app/hmi/`; rootfs overlay → `overlay/board/rockchip/rk3566_rk3568/lws-hmi-fs-overlay/`; Buildroot fragments → `overlay/buildroot/`.
- **Do not** run `make build-uboot` on ynh960 unless Innohi instructs.
- OpenSpec workflow: `.cursor/skills/openspec-*` when the user uses that flow.

## Verification

Before finishing implementation work:

- Docs-only: no build required.
- `app/hmi/`: `flutter analyze` / tests under `app/hmi/` when Dart changed.
- Overlay/rootfs: `make build-rootfs` should pass `scripts/verify-rootfs-overlay.sh`.
- After flash (device): `verify-boot` (Plan A boot KPI); `verify-env` (§3.4 platform stack).

## Documentation maintenance

When adding or renaming a `make` target, update **all** of:

1. `Makefile` `help` text
2. `README.md` → **Make commands**
3. Rebuild table in this file (if it affects post-change user commands)

Keep long command examples in **README.md**; keep agent-only rules (rebuild block, pipeline gotchas) here. Use **one command per line** in user-facing examples (no `&&` chains).

## Repository map

| Path | Role |
|------|------|
| `app/hmi/` | Flutter HMI → `overlay/.../opt/hmi` |
| `overlay/.../lws-hmi-fs-overlay/` | Rootfs overlay (systemd, scripts, `/opt/hmi` staging) |
| `overlay/buildroot/` | Defconfig fragments, package pins |
| `overlay/kernel/` | DTS / kernel config |
| `board/` | ynh960 defconfig, LCD params, boot logo |
| `prebuilt/` | Runtime binaries for rootfs |
| `scripts/apply-overlay.sh` | Patches SDK, syncs overlay into Buildroot |
| `Makefile` | All `make` targets |
