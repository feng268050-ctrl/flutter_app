## ADDED Requirements

### Requirement: make upgrade-app signs and serves app tar.gz for device download

The repository SHALL provide **`make upgrade-app`** that packages (or consumes) the selected app install tree as a **`tar.gz`**, produces a detached Ed25519 **`.sig`** via the same tooling/key as system OTA (`ota-sign.sh` / `OTA_SIGNING_KEY`), starts an ephemeral host HTTP server serving the archive and `.sig`, and triggers the device via **`/run/hmi/upgrade-app.cmd`** with **`download <url>`**. SSH SHALL be control-plane only (MUST NOT be the bulk transfer path). Device selection SHALL match other USB-SSH / `SN=` / `IP=` helpers. HTTP bind SHALL honor `OTA_HTTP_HOST` / `OTA_HTTP_PORT` with the same defaults family as `make upgrade` / peripheral upgrades. `APP=` SHALL select which app tree to package (default `lws_hmi` → `/opt/hmi`).

**`make push-app` SHALL be a Make alias of `make upgrade-app`** (identical signed HTTP + device download path). The host MUST NOT retain an unsigned SCP / staging hot-swap implementation for either target name.

#### Scenario: Host force app upgrade over USB-SSH

- **WHEN** the operator runs `make build-app` then `make upgrade-app` with signing configured and a reachable board
- **THEN** the host serves the signed `tar.gz` + `.sig` over HTTP
- **AND** writes `download <url>` to `/run/hmi/upgrade-app.cmd`
- **AND** the device downloads, verifies, installs to `/opt/hmi`, and restarts `hmi.service`

#### Scenario: push-app is the same signed path

- **WHEN** the operator runs `make push-app` with the same env as a successful `upgrade-app`
- **THEN** behavior matches `make upgrade-app` (sign, HTTP serve, device `download <url>`, verify, install, restart)
- **AND** MUST NOT perform unsigned SCP of `/opt/hmi` artifacts

#### Scenario: Missing signature refuses upgrade-app and push-app

- **WHEN** signing is not configured or the `.sig` cannot be produced
- **THEN** `make upgrade-app` and `make push-app` exit non-zero before writing the cmd file
- **AND** MUST NOT fall back to unsigned SCP of `/opt/hmi`

### Requirement: upgrade-app and push-app are documented

`make help`, README Make commands, `docs/make-commands.md`, and AGENTS.md rebuild guidance SHALL document `make upgrade-app` as the canonical remote app update and SHALL state that **`push-app` is an alias** of `upgrade-app` (signed path; no unsigned push). Daily app iteration SHALL recommend `make build-app` then `make upgrade-app` or `make push-app`. Docs MUST NOT list `upgrade-hmi` as a Make target or alias, and MUST NOT document an unsigned push workflow.

#### Scenario: help lists upgrade-app and push-app alias

- **WHEN** the operator runs `make help`
- **THEN** output mentions `upgrade-app` and that `push-app` is its alias
- **AND** MUST NOT advertise unsigned SCP hot-swap as a supported path
