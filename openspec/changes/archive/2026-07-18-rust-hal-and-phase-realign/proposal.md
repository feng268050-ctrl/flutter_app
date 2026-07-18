## Why

Next products will use **different motherboards, screens, and top-level Apps**, while sharing one embedded OS and one UI framework. Today’s hardware access lives in Flutter as Dart `*Controller` + shell helpers—good for ynh960 Demo, but not a portable Platform API. We need a **language-agnostic Rust HAL** (submodule, like the UI kit) so Apps never bind to board sysfs/D-Bus details, and we must **realign the P1–P5 roadmap** (CyberUI rename, HAL as P3.1, emulator/AI/Android/engine reorder) so the team builds toward a multi-product OS instead of a single-board app.

## What Changes

- Introduce a **Rust HAL** as a git submodule / package under this repo (parallel to CyberUI), developed alongside current work; migrate already-verified P2 hardware capabilities behind a stable Platform API.
- Public HAL naming follows **industry system-service style** (`HalClient`, `Capabilities`, `NetworkManager` / `NetworkDevice`, `BluetoothManager`, `AudioManager`, `TimeService`, …)—not Flutter `*Controller` as the portable contract (D12).
- Define **layer conventions**: Product App → Dart HAL client → Rust HAL (daemon and/or `.so`) → board/screen packs → kernel/BlueZ/sysfs; shell oneshots remain for boot/ops where appropriate.
- **BREAKING (gradual):** Flutter App MUST stop treating `Linux*Controller` as the long-term platform surface; Demo/product code depends on HAL client abstractions. Existing shell persist paths (`/var/lib/*`, libexec) stay until HAL owns the same contracts.
- **Absorb `platform-event-driven-ui`:** Event-driven observation (netlink / wpa ctrl / BlueZ D-Bus / udev / inotify / …) becomes a **HAL requirement** on cutover—not a separate Dart `Linux*` rewrite. That change is superseded.
- Rename UI framework to **CyberUI** (Frosted Glass design retained initially; design system may change later, SwiftUI-style). Packages: e.g. `packages/cyber_ui`, `packages/cyber_ime` (names final in design).
- **Update project plan** (`docs/flutter-pi-hmi-plan.md`, AGENTS.md phase references) to the new stage list (P1–P2.5 done; P3.0 CyberUI; P3.1 HAL; P3.2 emulator; P3.3 AI; P4 business; P5.0 Android; P5.1 engine upgrade).

## Capabilities

### New Capabilities

- `rust-hal`: Language-agnostic embedded HAL; **optional** capabilities with discovery; network **roles** (not fixed `eth0`/`wlan0`); board/screen packs; **excludes** product RGB LEDs; Dart thin client; Buildroot hooks.
- `cyber-ui`: CyberUI + IME Flutter packages (submodules); Frosted Glass default look; API stable enough that product Apps do not fork the kit for theme experiments.
- `board-screen-pack`: Compile-time board/screen pack layout (defconfig/DTS/capability set/role map/LCD params/radio plugin) consumed by HAL and image build—ynh960 is the first pack; screen pack optional for headless.
- `phase-roadmap`: Authoritative P1–P5 stage definitions and old→new phase mapping in project docs (documentation capability; no runtime).

### Modified Capabilities

- `linux-wifi`, `linux-ethernet`, `linux-bluetooth`, `linux-backlight`, `linux-media-audio`, `linux-display-orientation`, `linux-datetime`, `linux-http-client`, `p2-device-demo-ui`: Long-term requirement shifts from “Dart Linux*Controller is the platform API” to “HAL client is the platform API when the capability is present.” **`linux-gpio-rgb-led` stays product-local / out of portable HAL.** Exact deltas land in P3.1 implementation; this proposal records the intent.

## Impact

- **New repos/submodules:** Rust HAL crate(s); CyberUI / CyberIME (replacing planned `frost_ui` / `frost_ime` names).
- **App:** `app/hmi/lib/platform/**` becomes client or shrinks; Demo wiring injects HAL-backed implementations.
- **Rootfs:** Optional `hald` / `liblws_hal.so` + systemd unit; board profile under `/etc` or `/usr/share`; existing `/usr/libexec/*` and `/var/lib/*` contracts preserved or wrapped.
- **Build:** Cross-compile Rust for aarch64 in Docker/SDK; `make` targets for HAL; flutter-pi vs flutter-embedded-linux for P3.2 emulator.
- **Docs:** `docs/flutter-pi-hmi-plan.md` phase table and §6.3 FrostUI → CyberUI; AGENTS.md rebuild notes unchanged in spirit.
- **Related:** Former `platform-event-driven-ui` is **archived** at `openspec/changes/archive/2026-07-17-platform-event-driven-ui/` (merged here; see design D8).
