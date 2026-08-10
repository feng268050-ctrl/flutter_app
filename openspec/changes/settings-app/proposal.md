## Why

Platform system settings today live inside the product HMI (`app/lws_hmi`) Settings shell, mixed with welding-specific Advanced / Custom Home / cloud / peripheral pages. Operators and OEM work need a normal OS-style Settings app that shares OEM `board_profile` + `cyber_hal` without product gpio/modbus, installs beside `/opt/hmi` on the same rootfs, and replaces the abandoned Factory Test second-app slot — without a second flash path that risks wiping `/userdata`.

## What Changes

- **Add** Flutter app `app/settings` → `/opt/settings` (non-HMI; Flutter **3.41.9** pin; path deps `cyber_hal` / `cyber_ui` / `cyber_ime`).
- **Replace** rootfs auto-include / verify / docs convention `factory_test` → **`settings`** (`ensure-rootfs-apps`, `verify-rootfs-overlay`, Make/AGENTS/README/multi-app specs).
- **Add** board lifecycle: `settings-launch.sh`, static `settings.service` (no `WantedBy=multi-user`), `/usr/bin/settings` CLI, `switch-to-settings` / `switch-to-hmi`, bidirectional `Conflicts=` with `hmi.service`.
- **Add** HMI explicit entry (System Settings / gear) → `switch-to-settings`; Settings **Exit** → `switch-to-hmi`. Not Kernel-Version×5.
- **Ship** Settings IA as a flat ordered top-level list (About, Operating System, Storage, Wi‑Fi, Ethernet, Bluetooth, Proxy, SSH, Date & Time, Country/Region, Language, Unit, Display, Sound, Power Mode, Keyboard, Mouse, USB OTG) — logical plan group names are **not** UI section headers.
- **Copy** (HMI keeps): About identity reads, Wi‑Fi, Proxy, Date & Time, Country/Region, Language, Unit, Display, Sound, Power Mode (from HMI General).
- **Migrate** (HMI removes pages/nav): Ethernet, Bluetooth, SSH, Keyboard, Mouse, USB OTG.
- **Bluetooth** adapter alias / display name = `Brand + " " + Model` from Vendor Storage identity (Settings + HAL own policy after migrate).
- **Storage** sub-page shows capacity + **Secrets Seal** (`software` | `op-tee`) read-only.
- **Extend** HAL SysInfo / platform version probes for Operating System sub-page rows (missing → `—`, no crash).
- **Do not** move product-only Settings (Advanced, Custom Home, cloud, camera/control-board versions, process, HMI App OTA) into Settings.
- **BREAKING** (build/docs): second-app auto-include and verify paths that named `factory_test` become `settings`; do not create `app/factory_test`.
- **BREAKING** (product Settings UI): HMI Common/Input MUST drop the six migrated entries once Settings owns them.

## Capabilities

### New Capabilities

- `settings-app`: Independent Settings Flutter app — flat IA, landscape master-detail / portrait push, platform pages (copy + migrate), Exit, Bluetooth Brand+Model alias UX, Secrets Seal status, no product gpio/modbus.
- `settings-app-lifecycle`: Overlay launchers, static `settings.service`, CLI safety (`--stop-hmi`), `switch-to-*`, HMI entry / failure toast, mutual exclusion with `hmi.service`.

### Modified Capabilities

- `multi-app-build-select`: Auto-include / examples / “optional second app” from `factory_test` → `settings` (`/opt/settings`).
- `buildroot-lws-hmi-image`: Rootfs verify optional/required `/opt/settings` tree (not `/opt/factory_test`).
- `settings-ui`: Product HMI Settings removes migrated Network/Input rows (Ethernet, Bluetooth, SSH, Keyboard, Mouse, USB OTG); adds explicit System Settings entry; keeps copy items + product-only tabs.
- `hmi-systemd-boot`: `hmi.service` ↔ `settings.service` `Conflicts=`; boot default remains HMI-only.
- `dart-hal`: Read-only platform version / SELinux / Secrets Seal backend status for Settings OS + Storage pages (soft-fail).
- `linux-bluetooth`: Local adapter alias policy = Brand + space + Model from product identity.
- `p2-device-demo-ui`: Drop Demo/orphan routes for features migrated into Settings (Ethernet et al.); Demo cleanup may remove the whole P2 Demo when empty.
- `host-ota-publish`: Non-HMI example / wording that cited `factory_test` → `settings` (still not whole-device publish by default).

## Impact

- New: `app/settings/**`; overlay `settings-launch.sh`, `settings.service`, `/usr/bin/settings`, `switch-to-settings`, `switch-to-hmi`; post-build symlinks.
- Scripts/docs: `ensure-rootfs-apps.sh`, `verify-rootfs-overlay.sh`, `app-select.sh`, `Makefile` help, `AGENTS.md`, `README.md`, `docs/make-commands.md`, `app/README.md`, plan cross-links (`platform-os-oem-sdk-plan.md`).
- Packages: `cyber_hal` SysInfo / platform versions (+ optional Secrets Seal status); Bluetooth `setAlias` / adapter-alias path; shared presentation packages optional (copy-first OK).
- Product App: HMI System Settings entry; remove migrated pages/nav/Demo links; retain copy surfaces and product Settings tabs.
- Build: `APP=settings make build-app` / `push-app`; `make build-rootfs` auto-ensures `/opt/settings` when source exists; Engine/ICU remain shared under `/usr` (no second engine in Settings bundle).
- Source of truth for product decisions: `docs/settings-app-plan.md`.
