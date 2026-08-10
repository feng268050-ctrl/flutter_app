## Context

System OTA already uses: **Ed25519 sidecar `.sig`** (`ota-sign.sh` = SHA-512 then sign), **ephemeral host HTTP** (`ota-http-serve.py`), device **`download <url>`** on `/run/hmi/upgrade-ota.cmd`, verify against `/etc/ota/ed25519.pub`, then apply. Cloud publish writes `lws-hmi/{staging|release}.json` with `{version, filename, published_at, url}` via R2 presign.

Control-board and camera today:

| Path | Behavior |
|------|----------|
| `make upgrade-control-board` / `upgrade-camera` | SSH stream upload of `.bin` / `.zip` → `upgrade <path>` — **no sig, no host HTTP** |
| In-app | Bundled-only checkers + Modbus / CGI apply; **no cloud check** |
| Publish | None |

This change lifts peripheral host force and cloud delivery onto the system-OTA transport/trust shape while keeping product-specific apply (Modbus / CGI).

## Goals / Non-Goals

**Goals:**

- Host helpers: sign → serve → device download → verify → existing apply (`hostForce`).
- Publish newest CB/camera release firmware + `.sig` + `release.json` under `lws-hmi/control-board/` and `lws-hmi/camera/`.
- In-app manual + auto cloud check/download for both peripherals; **newest wins** vs bundled.
- Shared OTA pubkey; refuse unsigned host/cloud peripheral payloads before apply.
- Preserve mutex with system OTA and cross-peripheral sessions.

**Non-Goals:**

- Routing peripheral apply through `cyber_ota` A/B partition writes.
- Staging / `-beta` channel for CB or camera.
- RockUSB peripheral flash.
- Process-library cloud OTA.
- Implementing Worker allowlists in this repo (document sibling needs).
- Changing Modbus / CGI flash protocols themselves.

## Decisions

### 1. Reuse system OTA signing wire format and pubkey (not a second key)

**Choice:** Sign peripheral `.bin` / `.zip` with the same `scripts/ota-sign.sh` and verify with the same device `/etc/ota/ed25519.pub` / `OtaVerify` (or thin wrapper calling it on an arbitrary file path).

**Why:** One trust root already shipped; operators already run `make ota-release-keys`. Separate peripheral keys would double key distribution and confuse release ops.

**Alternatives rejected:** Unsigned host path (breaks parity with `make upgrade`); per-artifact nested tar (unnecessary indirection for a single blob).

### 2. Host helpers mirror `make upgrade` SSH path, not SSH upload

**Choice:**

```text
select firmware → ota-sign.sh → ota-http-serve.py (file + .sig)
  → SSH write /run/hmi/upgrade-{control-board|camera}.cmd:
       download <http://host:port/<basename>>
  → device GET file + .sig → verify → hostForce apply
```

Keep env parity where it fits: `OTA_HTTP_HOST` / `OTA_HTTP_PORT`, `OTA_SIGNING_KEY`, device select `SN=` / `IP=`. Overrides remain `FIRMWARE_BIN=` / `FIRMWARE_ZIP=`.

**Cmd contract evolution (BREAKING):**

| Before | After |
|--------|-------|
| `upgrade <local_path>` | `download <url>` (+ optional `cancel`) |
| File already on `/run/hmi/...` | Stage under `/userdata/ota/peripheral/` (or channel-specific subdir), verify, then apply |

Retain backward-compatible parse of legacy `upgrade <path>` for one transition if cheap; default docs/scripts only emit `download`.

**Why not keep SSH upload:** Large ZIPs stress SSH; unsigned; diverges from the proven OTA control-plane pattern.

### 3. Publish layout: nested under `lws-hmi/`, release-only

**Choice:** R2 keys (default `APP=lws_hmi` → artifact `lws-hmi`):

| Channel | Objects |
|---------|---------|
| Control-board | `lws-hmi/control-board/<basename>.bin`, `.bin.sig`, `release.json` |
| Camera | `lws-hmi/camera/<basename>.zip`, `.zip.sig`, `release.json` |

Manifest shape matches system OTA (no `sha512`):

```json
{
  "version": "1017",
  "filename": "LSW01H1000S1017.bin",
  "published_at": "…Z",
  "url": "<public_url>"
}
```

Camera example: `"version": "v1.0.7"` — SemVer only with leading `v`; build date stays in **`filename`** (`LTC609-v1.0.7 build20260513.zip`). Prefer **filename as SoT for typed parse** (SemVer then build). Manifest `version` for control-board is the bare software integer **`{SW}`** (no `v` prefix).

**Release only:** targets always write `release.json` (no `RELEASE=` toggle; no `staging.json`). Document that system `make publish` still has staging; peripherals do not.

**Newest selection at publish:** same rules as host helpers / ship-prune (CB: max SW per… publish **one** bin — see Decision 4; camera: newest SemVer then build for the product camera model(s) shipped).

**Auth / API:** reuse `publish_ota.py` patterns or a thin `publish_peripheral_firmware.py` sharing `cloud_api_base()` + presign PUT + token resolution from `publish-ota.sh`.

### 4. Multi-HW control-board publish strategy

**Choice (v1):** `make publish-control-board-firmware` publishes **one** selected bin (newest overall by SW, or `FIRMWARE_BIN=`), updating a single `lws-hmi/control-board/release.json`. Device applies only if HW matches; otherwise check reports unavailable / no update for that hardware.

**Why:** Matches current single-file host helper and keeps one manifest file like system OTA. Multi-HW channel arrays can be a follow-up if field fleets mix HW IDs under one cloud artifact.

**Alternative considered:** `release.json` as a list of HW-keyed entries — deferred to keep publish/client simple.

### 5. In-app check: compose bundled + cloud, newest wins

**Choice:** Extend CB and camera `UpgradeChecker` paths (or a thin compositor above them):

1. Resolve **bundled** candidate (existing gates).
2. If cloud services / pinned API origin allow, fetch `…/r2/lws-hmi/control-board/release.json` or `…/camera/release.json` (same `/r2/{…}` resolution style as system OTA; **always release**, ignore cloud tier staging).
3. Parse remote filename → typed version; if HW/model compatible and strictly newer than **live device**, it is a cloud candidate.
4. **Select offer:** `max(bundled, cloud)` by the same typed order; on tie prefer **bundled** (no download).
5. Operator confirm → if cloud selected, download URL + `.sig`, verify, then existing applicator; if bundled, existing asset load path.

**Auto-check:** One Device Information master switch **Auto-Check for Updates** (Versions group, last row) gates Product Home tips and auto-check-on-open for System Upgrade, control-board, and camera upgrade pages. Those pages MUST NOT host separate auto-check checkboxes. When the switch is on, Home tip continues once-per-process and SHOULD use the same compositor so a newer cloud build can tip even when bundled is stale (still confirm-gated; never auto-apply).

**Why always release for peripherals:** Proposal requirement; avoids shipping `-beta` camera/CB into prod fleets via tier confusion.

### 6. Verify + stage before apply; do not use full `OtaSession` apply

**Choice:** Reuse `OtaVerify` (and HTTP download helper) for the blob; then call `ControlBoardUpgradeCoordinator` / `CameraProgramUpgradeCoordinator` with local verified bytes/path. Do **not** run extract/dd.

Staging dirs: e.g. `/userdata/ota/control-board/` and `/userdata/ota/camera/` (durable across reboot if needed mid-session; clear on success/fail like OTA hygiene).

### 7. Docs and Make surface

New/updated targets in Makefile help + `docs/make-commands.md` + AGENTS rebuild table:

- `upgrade-control-board` / `upgrade-camera` (behavior change)
- `publish-control-board-firmware` / `publish-camera-firmware` (+ optional `publish-*-only`)

## Risks / Trade-offs

- **[BREAKING host cmd]** Old boards with only `upgrade <path>` watchers fail against new host scripts → Mitigation: ship App (`build-app`/`push-app`) before using new helpers; optional one-release dual-parse.
- **[R2 allowlist]** New keys may 403 on presign → Mitigation: document sibling api-server allowlist for `lws-hmi/control-board/*` and `lws-hmi/camera/*`.
- **[Single CB HW in release.json]** Wrong HW published → devices correctly refuse apply but operators may think publish “failed” → Mitigation: log HW in publish output; allow `FIRMWARE_BIN=`; follow-up multi-entry manifest if needed.
- **[Home + cloud]** Auto tip with cloud needs network on Home → Mitigation: soft-fail to bundled-only when cloud unreachable (same as system OTA check unavailable).
- **[Large camera ZIP on tmpfs]** Old `/run/hmi/` upload avoided by `/userdata/ota/` staging → Mitigation: document userdata space; clean after session.

## Migration Plan

1. Land App verify + `download` watchers + newest-wins checkers; push App to boards.
2. Land host script changes (sign + HTTP); operators need `OTA_SIGNING_KEY`.
3. Land publish targets; configure R2 allowlist; publish release firmware.
4. Ship Device Information Auto-Check for Updates master switch (default off or match product default); remove per-page auto-check checkboxes.
5. Rollback: keep reading legacy `upgrade <path>` briefly; publish can be unused without affecting bundled offline path.

## Open Questions

- Sibling Worker allowlist ownership — track as external checklist, not blocked for App/host implementation against api-test if keys already open.

**Resolved:** Home tips and page auto-check-on-open both honor the Device Information master Auto-Check switch (not independent of Settings).
