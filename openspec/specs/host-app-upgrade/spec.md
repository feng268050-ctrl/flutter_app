# Host App Upgrade Specification

## Purpose

Host `make upgrade-app`: sign and HTTP-serve the app `tar.gz`, device `download <url>` + Ed25519 verify + install to `/opt/hmi` + restart `hmi.service`. Debug unsigned hot-swap remains **`make push-app`** (`host-push-hmi`) and is not an alias of this target.

## Requirements

### Requirement: make upgrade-app signs and serves app tar.gz for device download

The repository SHALL provide **`make upgrade-app`** that packages (or consumes) the selected app install tree as a **`tar.gz`**, produces a detached Ed25519 **`.sig`** via the same tooling/key as system OTA (`ota-sign.sh` / `OTA_SIGNING_KEY`), starts an ephemeral host HTTP server serving the archive and `.sig`, and triggers the device via **`/run/hmi/upgrade-app.cmd`** with **`download <url>`**. SSH SHALL be control-plane only (MUST NOT be the bulk transfer path). Device selection SHALL match other USB-SSH / `SN=` / `IP=` helpers. HTTP bind SHALL honor `OTA_HTTP_HOST` / `OTA_HTTP_PORT` with the same defaults family as `make upgrade` / peripheral upgrades. `APP=` SHALL select which app tree to package (default `lws_hmi` → `/opt/hmi`).

**`make push-app` MUST NOT be a Make alias of `make upgrade-app`.** Unsigned SSH staging hot-swap is a separate debug target documented under `host-push-hmi`.

#### Scenario: Host force app upgrade over USB-SSH

- **WHEN** the operator runs `make build-app` then `make upgrade-app` with signing configured and a reachable board
- **THEN** the host serves the signed `tar.gz` + `.sig` over HTTP
- **AND** writes `download <url>` to `/run/hmi/upgrade-app.cmd`
- **AND** the device downloads, verifies, installs to `/opt/hmi`, and restarts `hmi.service`

#### Scenario: Missing signature refuses upgrade-app

- **WHEN** signing is not configured or the `.sig` cannot be produced
- **THEN** `make upgrade-app` exits non-zero before writing the cmd file
- **AND** MUST NOT fall back to unsigned SCP of `/opt/hmi`

### Requirement: upgrade-app is documented separately from push-app

`make help`, README Make commands, `docs/make-commands.md`, and AGENTS.md rebuild guidance SHALL document `make upgrade-app` as the signed remote app update (Cloud + Upgrade) and SHALL document **`make push-app`** as an unsigned **Debug** hot-swap (not an alias). Signed shipping SHALL recommend `make build-app` then `make upgrade-app`. Docs MUST NOT list `upgrade-hmi` or `apply-app-overlay` as Make targets.

#### Scenario: help lists upgrade-app without push-app alias

- **WHEN** the operator runs `make help`
- **THEN** output lists `upgrade-app` under Cloud + Upgrade and `push-app` under Debug as unsigned stream
- **AND** MUST NOT claim `push-app` is an alias of `upgrade-app`
