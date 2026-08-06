# Settings cloud OTA — board smoke

End-to-end: published channel → Device Information → **OTA Settings sub-page** → Check / **Update Now** → CyberUI **upgrade progress page** → verify/apply.

> UI path: dedicated OTA sub-page + redesigned progress page (change proposal / tasks §5).

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

   - Test/dev: `{pinnedApiBase}/view/lws-hmi/staging.json`
   - Prod: `{pinnedApiBase}/view/lws-hmi/release.json`

   **Record result:** HTTP status and whether JSON has `version` + `url` (no `package_url` required).

   Open question from design: if `/view/` is 404/auth-gated on the pinned Worker, note it here and fall back investigation (public R2 manifest URL vs Worker route).

3. Settings → Device Information → **OTA / system-update entry** → OTA sub-page:

   - Cloud off → **Check for Updates** shows unavailable (not “up to date”).
   - Cloud on + pinned origin → Check for Updates:
     - up to date, or
     - update available → **Update Now** (version / notes; Later dismisses).
   - After Update Now: laser/work stops, **CyberUI upgrade progress page** (not Home), download → verify → extract → burn → reboot hint.
   - Enable **Automatically check for updates**: should prompt / surface available state (no auto-apply).
   - Device Information MUST NOT still show the old inline OTA footer once the sub-page ships.

4. Optional WS: `command.check_update` / `command.update_system` against the same channel; progress frames during transfer/write.

5. Negative: corrupt or missing `.sig` → upgrade page fail; partitions not claimed updated.

## Pass criteria

- [ ] `/view/…/staging.json` (or release) GET succeeds with publish-shaped JSON
- [ ] Device Information opens OTA sub-page; check reflects newer channel without false “up to date” when URL missing
- [ ] Update Now → CyberUI progress page → verify with `.sig` → apply or clean failure
- [ ] Auto-check prompts only (no auto-apply)
