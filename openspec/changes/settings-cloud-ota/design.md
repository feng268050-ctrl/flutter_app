## Context

Whole-device OTA already has:

1. **Host publish** — channel JSON (`version`, `filename`, `published_at`, `url`) + archive `.sig`.
2. **Apply pipeline** — `cyber_ota` download → verify → extract → inactive-slot write; host `make upgrade` works.
3. **Coordinator / WS** — `SystemOtaCoordinator`, channel `url` parse, Settings footer check (interim).

Gaps vs product UX (and lws-ui):

- lws-ui: Device Information **Check for Updates** → **`UpgradeActivity`** (title / notes / **Update Now**, then progress). HMI currently inlines check on Device Information and uses a bare full-screen progress route that does not match CyberUI Settings / product chrome.
- HMI Settings pattern for focused features is a **`SettingsScaffold` sub-page** (Cloud services, Wi‑Fi, …), not a long Device Information footer.

This change finishes cloud discovery **and** aligns operator UI: OTA Settings sub-page + CyberUI upgrade progress page.

## Goals / Non-Goals

**Goals:**

- Parse published channel manifests (`url` / `package_url`).
- **Settings OTA sub-page** (CyberUI): check, auto-check, update-available + Update Now; Device Information only navigates here.
- **Upgrade progress page** restyled to system design tokens / Settings–Cyber chrome; shared by Settings, host upgrade, WS.
- Honest unavailable / fail / up-to-date outcomes; never auto-apply.
- Tests + smoke via sub-page path.

**Non-Goals:**

- Changing publish schema or A/B apply.
- Pixel-cloning Android mipmap layouts; use CyberUI / HMI Settings vocabulary instead.
- Requiring `title`/`content` in channel JSON (optional extras if present).
- Bundled control-board firmware UI.

## Decisions

### 1. Channel JSON: accept `url` as package location

- **Decision:** `package_url` if non-empty, else `url`; `.sig` defaults to archive URL + `.sig`.
- **Why:** Matches `host-ota-publish` / lws-ui channel shape.

### 2. Keep `/view/{artifact}/{channel}.json` as check URL

- **Decision:** Unchanged (`staging.json` / `release.json` by tier; artifact `lws-hmi`).

### 3. Version compare uses running HMI app version

- **Decision:** Unchanged; same-base `-beta` is older than release at that base.

### 4. Separate Settings OTA sub-page (lws-ui flow, HMI chrome)

- **Decision:** Add `SystemOtaSettingsPage` (name TBD) pushed via `pushSettingsPage` from Device Information (navigation row / primary entry — e.g. “System update” / Check for Updates). Page uses **`SettingsScaffold`** (CyberUI page status bar) + untitled **`SettingsGroup` / Cyber cards**:
  - Current system version readout
  - **Check for Updates** (`HmiButton` / primary CTA)
  - **Automatically check for updates** (`SettingsCheckboxRow`)
  - When newer: version headline + optional `title`/`content` (or l10n template from versions) + **Update Now** / Later — lws-ui `UpgradeActivity` idle phase
- Remove inline OTA footer from Device Information (keep identity / versions / focus cards).
- **Update Now** → `startCloudUpdateFlow` (safe shutdown → upgrade **progress** route). Auto-check prompts into this sub-page or shows the available state / dialog that leads to Update Now — never starts apply alone.
- **Why:** Matches HMI sub-page pattern and lws-ui separation of “decide to update” vs “run progress.”
- **Alternatives:** Keep footer on Device Information — rejected (user request + crowded tab). Full duplicate of Android layout assets — rejected (use CyberUI).

### 5. Redesign upgrade progress page with system design elements

- **Decision:** Restyle `SystemUpgradePage` (route `AppRoutes.systemUpgrade`):
  - Background / text from **CyberColors** (and related tokens), not ad-hoc Material-only look
  - Prefer shared Settings / Cyber panel or card chrome for the progress block where it fits a full-screen takeover
  - Phase copy already mapped (download / verify / extract / writing rootfs|kernel|oem); progress via Cyber-aligned indicators (`LinearProgressIndicator` themed or Cyber progress widget if one exists in-tree)
  - Failure / close actions use **`HmiButton` / CyberButton** patterns
  - During non-cancelable write: no back that cancels write (existing `PopScope` rules); page status bar back MAY be hidden or no-op while writing
  - Still **no** laser/job controls; host + cloud share this page
- **Why:** User asked to optimize the upgrade page to match system design; bare centered `Scaffold` is inconsistent with Settings / CyberUI.
- **Alternatives:** Keep minimal page — rejected. Embed progress inside Settings OTA sub-page — rejected (safe shutdown clears stack to dedicated route so work screens cannot fire laser).

### 6. Auto-check timing

- **Decision:** On OTA sub-page arm / enable auto-check: immediate check + periodic (6h). Failures silent for auto-check; manual check shows outcomes on the sub-page.

### 7. Trust boundary unchanged

- **Decision:** `.sig` still required before extract/apply.

## Risks / Trade-offs

- **[Risk] `/view/` broken on some Workers** → smoke GET; fix URL if needed.
- **[Risk] Operators miss OTA entry after moving off Device Information footer** → clear nav row label + l10n; smoke covers path.
- **[Risk] Same-version `-beta`** → document in smoke / make-commands.
- **[Trade-off] Optional notes without publish `content`** → version-based message is enough for Update Now gate.

## Migration Plan

1. `make build-app` / `make push-app`.
2. `make publish` staging newer than device.
3. Settings → Device Information → OTA sub-page → Check → Update Now → progress page.
4. Rollback: previous App; R2 unchanged.

## Open Questions

1. Worker public `GET /view/lws-hmi/staging.json` — confirm on board smoke.
2. Exact Device Information row title (l10n): prefer existing `checkUpdate` / `systemUpgradeTitle` vs new “System update” key — resolve at implement time to match lws-ui / ARB habits.
