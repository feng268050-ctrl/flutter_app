# AGENTS.md

Instructions for coding agents working in **lws-hmi**. Human-oriented overview and long command lists live in [`README.md`](README.md); this file adds agent-specific rules agents should follow automatically.

## Project overview

- **What:** Buildroot-based **embedded appliance OS** for Innohi boards (benchmark: **ynh960/961/962**) + Flutter HMI (`app/hmi/`). Direction: shared **CyberUI** + **`cyber_hal`** Dart package (submodule/packages), per-product Apps, board profiles for new motherboards/panels. **No** Rust `hald` Platform API.
- **Board SKUs (current line):** ynh960 → RK3566 (entry); ynh962 → RK3568B2 (mid); ynh961 → RK3568 (high). Same product line; **one firmware image is the near-term goal** for this line. **Validate on ynh960** — no per-SKU defconfig fork yet. Future products may use different boards/screens via packs + HAL package.
- **Phase roadmap:** See `docs/flutter-pi-hmi-plan.md` §1 (P1–P2.5 done; next P3.0 CyberUI, **P3.1 Dart HAL**, P3.2 emulator, P3.3 AI, P4 business, P5.0 Android, P5.1 engine). HAL design: `openspec/changes/dart-hal-package/`.
- **Hosts:** Linux builds natively in `linux-sdk/`; macOS uses Docker `linux/amd64` + a Docker volume for the SDK tree.
- **Outputs:** `output/firmware/boot.img` (FIT for `rootfs_a`), `boot_b.img` (same kernel, FIT for `rootfs_b`), `rootfs.img`, and factory `update.img`; Linux also has them under `linux-sdk/output/firmware/`.
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
# Flutter app only (board already has a working rootfs)
make build-app
make push-app

# Kernel / DTS / boot logo
make build-boot-logo
make build-kernel
make build-rootfs
make upgrade

# Overlay / systemd / LCD params (not app bundle)
make apply-overlay
make build-rootfs
make upgrade

# Or, for factory/USB deployment after any sequence above:
make build-img
make reboot-loader
make flash
```

More detail: [`docs/build-optimization.md`](docs/build-optimization.md), [`app/README.md`](app/README.md).

**Pipeline rules (do not get wrong):**

- `make build-app` updates overlay `/opt/hmi` and runs `apply-overlay`; it does **not** rebuild rootfs.
- App-only daily iteration: `make build-app` then `make push-app` (SSH hot-swap `/opt/hmi`). Do **not** require `build-rootfs` / `upgrade` unless baking the app into a release image or the board lacks a pushable HMI.
- `make build-kernel` builds two hash-valid FITs containing the same Linux kernel: `boot.img` selects `rootfs_a`; `boot_b.img` selects `rootfs_b`. Publishes them to `output/firmware/` (macOS Docker volume auto-export).
- `make build-rootfs` bakes fs-overlay (including `/opt/hmi`) into rootfs and publishes `output/firmware/rootfs.img`.
- `make build-img` does **not** compile kernel or rootfs; it packages existing loader/U-Boot/misc/dual-FIT/rootfs artifacts into factory `output/firmware/update.img`.
- Full-system `make upgrade` does **not** send `update.img`; it **streams** `rootfs.img` and the inactive letter’s FIT into partitions (helpers only under `/userdata/ota/`), returns when board apply reports `apply.status=ok` (reboot requested) or SSH drops, and intentionally does not wait for post-reboot SSH or health. Online OTA stays download-then-staged-apply via `ab-upgrade-apply.sh`.
- Prefer `make upgrade` for rootfs/kernel daily iteration after the board has the P2.4 GPT/helpers. Always run `make build-img` when producing a release/factory artifact; use `make reboot-loader` then `make flash` when validating that artifact. Do **not** require a manual `make docker-export-artifacts` after kernel/rootfs builds.

## Rebuild instructions for the user (required)

After **any non-docs code change**, end your reply with a **「重新构建」** block. The user does not know which paths you touched — list exact `make` lines, **one per line**, in order. Omit `make flash` if they build on Linux and flash elsewhere.

| What changed | Commands |
|--------------|----------|
| `app/hmi/**`, `scripts/build-app.sh`, `scripts/push-app.sh` | `make build-app`, `make push-app` |
| Bake app into rootfs / A/B image (release or no push path) | `make build-app`, `make build-rootfs`, `make upgrade` |
| `board/logo/**` | `make build-boot-logo`, `make build-kernel`, `make upgrade` |
| `overlay/kernel/**`, kernel DTS | `make apply-overlay`, `make build-kernel`, `make build-rootfs`, `make upgrade` |
| `overlay/.../rootfs-overlay/**` (not app) | `make apply-overlay`, `make build-rootfs`, `make upgrade` |
| USB plug-ssh (`overlay/kernel/**` + fs-overlay scripts/units) | `make apply-overlay`, `make build-kernel`, `make build-rootfs`, `make upgrade` |
| `scripts/device-logs.sh` only (host log streaming) | none |
| `scripts/debug-app*.sh`, `scripts/debug-host-prepare.sh`, `scripts/debug-custom-device/**`, `scripts/debug-setup.sh`, `scripts/build-debug-app.sh` (host only; board already has P1.5 overlay) | `make debug-setup`, `make debug-app` |
| `overlay/.../rootfs-overlay/**` debug scripts (`hmi-launch.sh`, `debug-app-*`, `hmi.service`) | `make apply-overlay`, `make build-rootfs`, `make upgrade` |
| `overlay/buildroot/**` | `make apply-overlay`, `make check-prebuilt`, `make build-rootfs`, `make upgrade` |
| `prebuilt/**`, runtime recipes | `make build-runtime-deps` (or specific target), `make apply-overlay`, `make build-rootfs`, `make upgrade` |
| `board/*.txt` LCD/MIPI params | `make apply-overlay`, `make build-rootfs`, `make upgrade` |
| `board/parameter-buildroot-fit.txt` (GPT / A/B) | `make apply-overlay`, `make build-img`, `make flash` (repartition once) |
| A/B upgrade helpers (`overlay/.../ab-*.sh`, `ab-boot-confirm.service`) | First adoption: `make apply-overlay`, `make build-rootfs`, `make build-img`, `make flash`; existing P2.4 board: `make apply-overlay`, `make build-rootfs`, `make upgrade` |
| `scripts/upgrade-remote.sh`, `scripts/stream-file-progress.py`, or Makefile `upgrade` only (board already has P2.4 overlay + A/B GPT) | `make upgrade` (no firmware rebuild unless image inputs are stale) |
| Host device registry/reboot paths (`scripts/ssh-devices.sh`, `scripts/flash-usb.sh`) | no firmware rebuild; exercise the affected `make devices` / `make reboot` / `make reboot-loader` flow |
| Release / factory artifact | Build all changed inputs, then `make build-img`; for hardware validation: `make reboot-loader`, `make flash` |
| `fetch-*`, `extract-linux-sdk`, `build-dev-deps` only | no firmware rebuild; name the fetch/extract/build-deps target |
| Docs only | none |

Example:

```text
重新构建（本次改动了 app）：
make build-app
make push-app
```

When unsure or on a clean tree: `make build`.

## Code conventions

- **Minimize scope** — smallest correct diff; no drive-by refactors.
- **Match existing style** in touched files (shell, Dart, Buildroot `.mk`, overlay layout).
- **Script / device-command naming** — prefer **verb + noun** (kebab-case), no product prefix on script basenames. Operator commands → `/usr/bin/<verb-noun>` via `post-build.sh`. Helpers → **`/usr/libexec/{wpa,network,bluetooth,hmi}/`**. State → **`/var/lib/{wpa_supplicant,network,bluetooth,hmi}/`**. systemd units use **functional** names (`wlan-wpa.service`, `settings-restore.service`); UI daemon only: `hmi.service`.
- **Paths:** app → `app/hmi/`; rootfs overlay → `overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/`; Buildroot fragments → `overlay/buildroot/`.
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
| `overlay/.../rootfs-overlay/` | Rootfs overlay (systemd, scripts, `/opt/hmi` staging) |
| `overlay/buildroot/` | Defconfig fragments, package pins |
| `overlay/kernel/` | DTS / kernel config |
| `board/` | ynh960 defconfig, LCD params, boot logo |
| `prebuilt/` | Runtime binaries for rootfs |
| `scripts/apply-overlay.sh` | Patches SDK, syncs overlay into Buildroot |
| `Makefile` | All `make` targets |
