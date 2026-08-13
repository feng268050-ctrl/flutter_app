# Device / host contracts (unified OTA)

## Staging directory

Default: `/userdata/ota/` (`OTA_DIR` override on board helpers).

| Path | Role |
|------|------|
| `ota-package.tar.gz` | Incoming / staged OTA archive (device HTTP download) |
| `ota-package.tar.gz.sig` | Detached Ed25519 (**required** for cloud and host SSH upgrade) |
| `ota.log` | Append-only debug log from Dart `OtaSession` |
| `apply.status` | Legacy one-line status (`running` / `ok` / `fail`) — written by Dart `OtaApply` |
| `manifest.json` | Inside archive after extract (orchestration digests; not the cloud check-update manifest) |
| `boot.img` / `boot_b.img` / `rootfs.img` / `oem.img` | Extracted members |

## Package-internal `manifest.json` (`make ota-package`)

Orchestration only — **not** the trust root (trust is the archive `.sig`). Shape:

```json
{
  "format": "lws-ota-tar-v1",
  "app": "lws_hmi",
  "oem_only": 0,
  "created_at_unix": 0,
  "files": {
    "boot.img": { "sha256": "…", "size": 0 },
    "boot_b.img": { "sha256": "…", "size": 0 },
    "rootfs.img": { "sha256": "…", "size": 0 },
    "oem.img": { "sha256": "…", "size": 0 }
  }
}
```

`files` lists each packed `*.img` with sha256 + size. Cloud check-update manifests (`version` + `package_url`) are a separate document served over HTTP.

## Progress (Stream only)

UI and cloud WebSocket progress SHALL subscribe to `OtaSession.progress` (via `SystemOtaCoordinator`). There is **no** `progress.json`. Debug lines are appended to `/userdata/ota/ota.log`.

`OtaProgress.toJson()` remains the **WS wire payload** shape:

```json
{
  "phase": "idle|preparing|transferring|verifying|extracting|writing|arming|ok|fail",
  "percent": 0,
  "bytes_received": 0,
  "bytes_total": 0,
  "ingress": "cloud|host|local",
  "message": "",
  "error_code": "",
  "updated_at_ms": 0
}
```

### Phase progress model (as implemented)

| Phase | Percent / bytes | `message` (stable UI key) |
|-------|-----------------|---------------------------|
| `transferring` | Archive download bytes / total | Download UX |
| `verifying` | 0 → 100 (gate) | Signature verify |
| `extracting` | Compressed archive bytes fed to `tar -xz` stdin / archive size | Extracting package |
| `writing` | **Per image** 0–100 (not one combined axis across images) | See below |
| `arming` / `ok` | 100 | Reboot / complete |

**Writing order** (full-system, matches retired stream `make upgrade`):

1. inactive `rootfs.img` → inactive `rootfs_*` — `message=writing rootfs`
2. `boot` → `boot_b` backup (no separate UI label; keep `writing kernel` at **0%**)
3. inactive letter FIT (`boot.img` or `boot_b.img`) → `boot` — `message=writing kernel` with byte progress
4. optional `oem.img` → `oem` — `message=writing oem`
5. arm try-boot + reboot

Within `writing`, when `message` / `bytes_total` changes to the next image, percent MAY restart at 0. Do **not** show a distinct “backing up boot” status.

**Write / extract I/O:** chunked feed like host `stream-file-progress.py` — read source file in chunks, pipe to `dd of=<dev>` or `tar -xz` stdin (do not open `/dev` via Dart `RandomAccessFile`; do not use elapsed-time fake progress).

Upgrade-page l10n maps `message` keys to operator strings (`Writing rootfs…`, `Writing kernel…`, `Writing oem…`).

## Host trigger: `/run/hmi/upgrade-ota.cmd`

Same claim pattern as control-board / process-library watchers (HMI clears file after read).

| Line | Meaning |
|------|---------|
| `download <package_url> [oem_only=0\|1]` | Safe shutdown → dedicated upgrade page; HTTP GET `package_url` and sibling `.sig`; `ingress=host`; verify then extract/apply. |
| `cancel` | Abort before write phase when still cancelable. |

Host sequence (SSH `make upgrade`):

1. Preflight slot state (`ab-preflight.sh`).
2. Ensure `make ota-package` produced `tar.gz` + `.sig`, **or** `UPGRADE_PACKAGE=<archive>` with sibling `<archive>.sig` in the same directory.
3. `mkdir -p /userdata/ota`; clear stale package/progress/sigs.
4. Start ephemeral host HTTP server (bind USB-SSH `192.168.55.2` or LAN source IP; override `OTA_HTTP_HOST=` / `OTA_HTTP_PORT=`) serving only the archive + `.sig`.
5. Write `download <http://host:port/ota-package.tar.gz> …` → device pulls both files via the same HTTP client as cloud OTA.
6. Host waits until the HTTP server reports `TRANSFER_COMPLETE` (archive + `.sig` fully GET; send progress on stderr), then exits successfully. Device verify/apply/reboot continue on-board; host does **not** claim apply success.

## `UPGRADE_PACKAGE` sibling `.sig`

When `UPGRADE_PACKAGE=/path/to/foo.tar.gz` (or `.tar` / `.tgz`):

- Default signature path: **`/path/to/foo.tar.gz.sig`** (archive path + `.sig`).
- SSH: both files MUST exist and be readable; host HTTP serves both; device verifies.
- RockUSB: `.sig` is not required for `di` (unsigned path).

## Transfer → transferring mapping

- **Host `make upgrade`:** device HTTP **download** callbacks set `bytes_*` / percent (`ingress=host`).
- **Cloud:** same HTTP download path (`ingress=cloud`); UX label remains「下载」.
- After transfer complete: `verifying` → `extracting` → `writing`.

## Archive members (`make ota-package`)

Full-system (default): `boot.img`, `boot_b.img`, `rootfs.img`, optional `oem.img`, plus orchestration `manifest.json`.

`OEM_ONLY=1`: `oem.img` + `manifest.json` only.

## RockUSB Loader (not this staged contract)

`UPGRADE_TRANSPORT=rockusb` / Loader Maskrom `di` writes **both** letters (`boot`+`boot_b`, `rootfs_a`+`rootfs_b`, optional oem) — unsigned, no try-boot arm. It does **not** mirror the SSH inactive-only sequence.
