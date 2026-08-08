## Why

Control-board and camera firmware can already be force-flashed from the host and offered from App-bundled assets, but those paths still **SSH-upload unsigned payloads** and have **no cloud publish / check / download**. System OTA already solved trust and transfer with Ed25519 sidecar `.sig`, ephemeral host HTTP, device pull, and `make publish` → R2 `release.json`. Operators and field devices need the same transport/trust model for peripheral firmware, plus cloud updates that compete fairly with the offline bundled copy (newest wins).

## What Changes

- **BREAKING (host helpers):** `make upgrade-control-board` and `make upgrade-camera` switch from SSH bulk upload + `upgrade <local_path>` to the **system-OTA shape**: sign payload → ephemeral host HTTP → device `download <url>` (+ sibling `.sig`) → verify → existing Modbus / CGI apply. SSH remains control-plane only.
- Add **`make publish-control-board-firmware`** and **`make publish-camera-firmware`** (and optional `*-only` variants if useful), mirroring `make publish` presign PUT to R2 under **`lws-hmi/control-board/`** and **`lws-hmi/camera/`**, with firmware + `.sig` + **`release.json` only** (no staging / `-beta` channel for these peripherals).
- Extend in-app control-board and camera upgrade flows with **manual Check for Updates** and **automatic check** against those cloud channel manifests (same product cloud origin / tier rules as system OTA for API base), then download + verify + apply via existing applicators.
- **Newest-wins policy:** when both bundled and cloud candidates exist for the same peripheral (matching HW / model rules), the App selects the **newer** payload; equal versions prefer local/bundled to avoid unnecessary download; host force still skips version gates.
- Reuse the **same OTA Ed25519 keypair** (`ota-sign.sh` / `/etc/ota/ed25519.pub`) for peripheral blobs; do not invent a second trust root.
- Docs: Makefile help, `docs/make-commands.md`, README Make examples, AGENTS rebuild rows.

**Non-goals:** changing whole-device A/B apply / `cyber_ota` partition writes; RockUSB paths for peripherals; process-library cloud OTA; staging channel for CB/camera; Worker/api-server implementation (client + R2 key layout only; sibling allowlist if needed).

## Capabilities

### New Capabilities

- `host-peripheral-firmware-upgrade`: Host `make upgrade-control-board` / `make upgrade-camera` use signed sidecar + host HTTP + device download (mirroring SSH `make upgrade`), then trigger existing in-app peripheral apply with host-force policy.
- `host-peripheral-firmware-publish`: Host `make publish-control-board-firmware` / `make publish-camera-firmware` upload newest release firmware + `.sig` + `release.json` to `lws-hmi/control-board` and `lws-hmi/camera` via the same presign path as `make publish`.
- `peripheral-firmware-cloud-ota`: In-app manual/auto cloud check and signed download for control-board and camera firmware; coordinate with bundled assets using newest-wins selection; never auto-apply without operator confirm (except host-force).

### Modified Capabilities

- `startup-bundled-firmware-upgrade`: Host helper no longer SSH-uploads the `.bin`; Home/Settings candidate selection considers cloud when available and picks newest vs bundled.
- `camera-program-upgrade`: Host helper no longer SSH-uploads the ZIP; Settings/Home check path considers cloud + bundled newest-wins; download/verify precedes CGI flash.
- `ota-package-signing`: Document that the same Ed25519 wire format and device pubkey also gate **peripheral firmware blobs** (`.bin` / `.zip`) for host HTTP and cloud paths—not only system OTA `tar.gz`.

## Impact

- **Host:** `scripts/upgrade-control-board.sh`, `scripts/upgrade-camera.sh`, new publish scripts (or shared peripheral publish helper), Makefile targets / help, docs / AGENTS.
- **App:** command watchers (`download <url>`), verify via existing OTA verify helper, CB/camera checkers & coordinators, Settings upgrade pages (manual Check for Updates; Auto-Check master switch on Device Information), Home tip selection inputs, safe-update prep (stop work / quiesce+restore radios), camera C002 quiet during flash.
- **Cloud / R2:** new prefixes `lws-hmi/control-board/` and `lws-hmi/camera/` with release-only manifests; may need sibling api-server key allowlist.
- **Trust:** shared `/etc/ota/ed25519.pub`; unsigned peripheral host/cloud paths MUST refuse apply.
- **Mutex:** keep `FirmwareUpgradeCoordinator` rules so peripheral cloud download/apply cannot race control-board Modbus, camera CGI, or system OTA.
