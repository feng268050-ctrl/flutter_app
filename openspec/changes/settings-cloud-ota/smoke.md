# Settings cloud OTA — board smoke

End-to-end: published channel → Device Information → **System Version** → **System Upgrade** (full-height Settings card) → Check / Update Now → progress on the **same** page → verify/apply.

> UI: Device Information opens System Upgrade via System Version; Check + auto-check live on System Upgrade; results/progress in-card (no dialogs); `make upgrade` uses progress-only.

## Prerequisites

- Board already has whole-device OTA stack (Ed25519 pubkey at `/etc/ota/ed25519.pub`, openssl, A/B helpers).
- App with this change: `make build-app` then `make push-app`.
- Cloud services enabled on device; environment tier **test** or **dev** for staging (prod → `release.json`).
- Host can `make publish` (signed `ota-package` + token).

## Version caveat

Device compares channel `version` to running HMI `kSystemVersion` / pubspec. A staging build at the **same** numeric base (e.g. device `1.0.40`, channel `v1.0.40-beta`) is **older** than the release build — Check for Updates will say up to date. Publish a **higher** base for smoke (e.g. bump app version then `make publish`, or temporarily lower device version).

## Steps

1. On host, ensure images exist, then publish staging newer than the board:

   ```bash
   make publish
   ```

   Note printed `manifest_url` / `artifact_url` / `sig_url`.

2. On device (or from host via curl through the same API base the board pinned), GET the channel URL Settings will use:

   - Test/dev: `{pinnedApiBase}/r2/lws-hmi/staging.json`
   - Prod: `{pinnedApiBase}/r2/lws-hmi/release.json`

   **Record result:** HTTP status and whether JSON has `version` + `url` (no `package_url` required).

   Prefer `/r2/lws-hmi/…` until Worker allowlists `lws-hmi` on `GET /view/…`
   (`/view/lws-hmi/staging.json` is currently `ROUTE_NOT_FOUND`; `/r2/…` returns published JSON).

3. Settings → Device Information:

   - **System Version** row navigates to **System Upgrade** (chevron).
   - System Upgrade: one content card fills remaining height; hosts **Check for Updates** + **Automatically check for updates**.
   - Check **result stays in the content card** (no dialog): unavailable / failed / up to date / available + Update Now / Later.
   - After Update Now: progress on the **same** full-height card (download → verify → extract → burn → reboot hint).
   - Auto-check: when a newer package exists, opens System Upgrade with the available state (no auto-apply).
   - Host `make upgrade`: navigates to System Upgrade **progress-only** (no check footer).

4. Optional WS: `command.check_update` / `command.update_system` against the same channel; progress frames during transfer/write.

5. Negative: corrupt or missing `.sig` → upgrade page fail; partitions not claimed updated.

## Pass criteria

- [ ] `/r2/…/staging.json` (or release) GET succeeds with publish-shaped JSON
- [ ] Device Information System Version → System Upgrade; Check + checkbox on upgrade page
- [ ] Content card fills remaining height; check result in-card (no dialog)
- [ ] `make upgrade` progress-only (no check footer)
- [ ] Auto-check surfaces available only (no auto-apply)
