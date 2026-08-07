## Why

Owned `linux-sdk/buildroot` still reports **Buildroot 2024.02** (Rockchip/Innohi fork of the previous LTS). Upstream **2024.02** is past its LTS window, while the current Buildroot LTS line is **2025.02.x** (supported through **March 2028**, tip at propose time **2025.02.16**). Staying on 2024.02 leaves package recipe/infrastructure security and bugfix debt, forces product overlays (OpenSSL 3.5.x, GStreamer, BlueZ, Meson) to paper over an aging base, and blocks clean tracking of monthly LTS point releases. An appliance OS should ride the **3-year LTS**, not the three-month stable that EOLs in months.

## What Changes

- Rebase/merge owned **`linux-sdk/buildroot`** from Rockchip **2024.02** onto upstream **Buildroot 2025.02.x LTS** tip (floor at propose: **≥ 2025.02.16**; lock exact tag at implement time).
- Prefer **LTS 2025.02.x** over current three-month stable (**2026.05.1**, EOL **September 2026**) for product longevity.
- Preserve Rockchip/Innohi Buildroot deltas required for RK356x rootfs (board configs, `package/rockchip/**`, Mali/MPP/RGA/Weston integration, external GCC 10.3 toolchain fragment, `build.sh` rootfs path).
- Re-validate and adjust git-tracked **`overlay/buildroot/`** (chips fragments, `package/**` pins, `apply-overlay` sync helpers) so they apply cleanly on the new baseline; keep custom packages on overlay (do not move into `linux-sdk`).
- Record a tracked Buildroot version pin (docs + optional `overlay/buildroot/BUILDROOT_VERSION`) and a post-upgrade rebuild/smoke path (`clean-buildroot-output` → lunch → rootfs → upgrade).
- **BREAKING** for local developer trees: existing `buildroot/output/` stamps from 2024.02 are not reusable across the major bump — require a clean Buildroot output rebuild (and macOS Docker volume refresh when applicable).
- **Out of scope:** Jumping to 2026.05.x / master; replacing the Rockchip external toolchain with Buildroot-internal gcc/glibc in this change; kernel 6.1 work; committing `linux-sdk/` (S4); rewriting Flutter/engine prebuilt pipelines except where BR infra forces recipe fixes.

## Capabilities

### New Capabilities

- `buildroot-lts-baseline`: Product policy to track Buildroot **2025.02.x LTS** (version floor/pin, monthly point-release cadence, no-primary cherry-pick of individual package CVEs when the LTS tip already carries the fix), owned-tree rebase workflow, and verify/`BR2_VERSION` acceptance.

### Modified Capabilities

- `linux-sdk-own-tree`: Document that Buildroot LTS rebases land in owned `linux-sdk/buildroot` while **`overlay/buildroot/**` remains git SoT** for product fragments and package pins; record the baseline version for colleagues without a committed SDK.
- `buildroot-lws-hmi-image`: After this change, product rootfs builds MUST run on the pinned 2025.02.x baseline (`BR2_VERSION` / documented pin), not 2024.02; defconfig composition and platform package presence requirements remain in force on the new base.
- `buildroot-libopenssl`: Clarify that the OpenSSL 3.5.x overlay recipe is expected to align with the 2025.02.x Buildroot package shape (already noted in `apply-overlay`); re-sync after baseline bump.
- `buildroot-gstreamer-security`: Product GStreamer overlay pin MUST continue to inject on every `apply-overlay` against the new BR tree; rebuild stamps after major BR bump.
- `buildroot-bluez-security`: Same overlay-inject + explicit package rebuild expectations on the new baseline.

## Impact

- **SDK (gitignored):** `linux-sdk/buildroot/**` — major version rebase; expect Rockchip package/`Config.in` conflict triage.
- **Git SoT:** `overlay/buildroot/chips/**`, `overlay/buildroot/package/**`, `scripts/apply-overlay.sh` (sync_* helpers), possibly `scripts/br-make-packages.sh` / clean helpers; `docs/linux-sdk-vendor-import.md` (+ AGENTS rebuild notes if new Make helpers appear).
- **Build pipeline:** First landing needs `make clean-buildroot-output` (or equivalent), `make lunch`, full `make build-rootfs` (and likely `make build-runtime-deps` / package dircleans for overlay-pinned pkgs), then `make upgrade`. Prebuilt Flutter/GStreamer/platform exports may need re-export if staging ABI or host tools change.
- **Runtime risk focus:** systemd/networkd, wpa/BlueZ, Weston + eLinux HMI, OpenSSL, GStreamer/MPP preview, OP-TEE client, curl/openssl OTA verify — smoke on ynh960 after A/B upgrade.
- **Emulator note:** `scripts/fetch-emulator-swgl.sh` glibc floor comments may need update if the external toolchain / rootfs libc story changes as a side effect (secondary; only if measured).
