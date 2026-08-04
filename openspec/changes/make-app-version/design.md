## Context

`lws-ui` already has `make version` / `make version-bump` via `scripts/make/app-version.sh`, editing Android `versionName` / `versionCode` with encoding `major*1000 + minor*100 + patch` (e.g. `1.0.27` → `1027`). This repo’s product version lives in Flutter `app/<APP>/pubspec.yaml` as `version: x.y.z+build`, and `lws_hmi` additionally hard-codes `kSystemVersion` / `kSystemVersionCode` in `lib/app_version.dart` for Settings, cloud, and mDNS. `APP=` selection already exists (`scripts/app-select.sh`). Cloud publish (`make-publish-ota`) will read the pubspec semver as the sole OTA channel version.

Operators want the same Make UX here, but with a **5-digit** build number so minor can use two digits without colliding with patch: `v1.0.40` → `10040`.

## Goals / Non-Goals

**Goals:**

- Host-only Make targets to print and bump the selected app’s Flutter version.
- Reuse `APP=` / `app-select.sh` (default `lws_hmi`).
- Deterministic encode/decode: `build = major*10000 + minor*100 + patch`, printable as 5 digits for in-range values (leading zeros not required in the integer, but `10040` style).
- Reject overflows (major > 9, minor > 99, patch > 99) and reject `+build` that does not match the encoded value.
- Keep `app_version.dart` in sync when present under the selected app.

**Non-Goals:**

- Changing OS / kernel / Buildroot / OEM versioning.
- Auto-bump on every build or CI tag generation.
- Migrating historical device records that already stored 4-digit `versionCode` (document one-time bump only).
- Bumping package versions under `packages/*`.
- Implementing cloud publish itself (separate change).

## Decisions

### 1. Script location and CLI shape

**Choice:** `scripts/app-version.sh` with subcommands `print` | `bump <VERSION>`, invoked from Makefile like lws-ui.

**Why:** Matches sibling repo UX; verb-noun script basename fits AGENTS conventions; keeps Make thin.

**Alternatives:** Inline Make/`sed` only — rejected (harder to test overflow rules). Put under `scripts/make/` — optional; prefer repo-root `scripts/` where other host helpers live.

### 2. Source of truth and Dart sync

**Choice:** Authoritative line is `app/<APP>/pubspec.yaml` `^version:`. On bump, rewrite that line to `version: x.y.z+NNNNN`. If `app/<APP>/lib/app_version.dart` exists, also set `kSystemVersion` / `kSystemVersionCode` to match. Apps without that file (e.g. future `factory_test`) only get pubspec updates.

**Why:** Product UI/cloud already import Dart constants; hand-sync is the current failure mode.

**Alternatives:** Generate Dart from pubspec at build time — out of scope; larger App change.

### 3. Semver field budgets and encoding

**Choice:**

| Field | Display | Allowed range | Contribution to build |
|-------|---------|---------------|------------------------|
| major | `x` in `x.y.z` | 0–9 | `* 10000` |
| minor | `y` | 0–99 | `* 100` |
| patch | `z` | 0–99 | `* 1` |

Example: `1.0.40` → `1*10000 + 0*100 + 40` = `10040`.

Parse name as `^([0-9])\.([0-9]{1,2})\.([0-9]{1,2})$` then range-check after decimal parse (so `1.00.40` and `1.0.40` both OK; `1.100.0` fails). Reject if any component exceeds its max **before** writing.

Optional `VERSION=x.y.z+build`: if `+build` omitted, compute encode; if present, must equal encode exactly.

**Why:** Matches the user’s 1|00|40 digit layout; clearer than lws-ui’s patch≤100 quirk.

**Alternatives:** Keep 4-digit for Android parity — rejected (user request). Use full Flutter-unconstrained build integers — rejected (OTA/compare want compact monotonic codes within digit budgets).

### 4. `make version` output

**Choice:** Print `name+build` on one line (e.g. `1.0.40+10040`), same as lws-ui. Read from pubspec; do not require Dart file. If pubspec `+build` disagrees with encode(name), **print** still shows stored values but `version-bump` always writes a consistent pair; optionally warn on print mismatch (nice-to-have, not required).

### 5. Makefile / docs

**Choice:**

```make
version:
	@scripts/app-version.sh print

version-bump:
	@test -n "$(VERSION)" || (echo 'ERROR: VERSION is required...' >&2; exit 1)
	@scripts/app-version.sh bump "$(VERSION)"
```

Pass through `APP` from Make env (already common). Update `help`, README, AGENTS rebuild table: host-only → exercise `make version` / `make version-bump`; no firmware rebuild.

## Risks / Trade-offs

- **[Risk] Existing `1.0.38+1038` ≠ encode5** → Mitigation: this change sets `lws_hmi` to **`1.0.40+10040`** so name/build agree under the new scheme. `10040` > `1038`, so naive integer “newer” compares still work for devices on the old code.
- **[Risk] Digit exhaustion at patch 99 / minor 99 / major 9** → Mitigation: fail loudly; operators bump the next higher field manually with a new `VERSION=`.
- **[Risk] `sed` portability (macOS vs Linux)** → Mitigation: same Darwin `sed -i ''` vs GNU `sed -i` pattern as lws-ui script.
- **[Trade-off] minor display drops leading zeros** (`1.0.40` not `1.00.40`) while build uses two minor digits — acceptable; encoding uses numeric values.

## Migration Plan

1. Set `lws_hmi` to `1.0.40+10040` in `pubspec.yaml` and `lib/app_version.dart` (done as part of this change).
2. Land `scripts/app-version.sh` + Make targets; verify `make version` prints `1.0.40+10040`.
3. Rollback: revert script/Make and restore previous `version:` / Dart constants from git.

## Open Questions

- None.