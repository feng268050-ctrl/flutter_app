## Context

- **Current state**: `app/build.gradle.kts` sets `versionName = "1.0.27"` and `versionCode = getGitCount()` (git commit count). The root `Makefile` already parses `versionName` via `sed` for `APP_VERSION_NAME`, pack names, and help text.
- **Reference**: `lasercyber_mobile` uses `make version` / `make version-bump VERSION=x.y.z+build` on `pubspec.yaml`. This repo mirrors that UX on Gradle.
- **Constraints** (product rule): major and minor are **one digit** each (`0`–`9`); patch is **0–100**; build is a positive integer after `+`.

## Goals / Non-Goals

**Goals:**

- `make version` prints one line: `{versionName}+{versionCode}` from `app/build.gradle.kts`.
- `make version-bump VERSION=…` validates format, updates `versionName` and `versionCode` literals in place, and prints the new combined version.
- Help text documents both targets and the VERSION example (`1.0.8+108`).
- Validation fails fast with a clear message when VERSION is malformed or patch > 100.

**Non-Goals:**

- Automating version bumps in CI/GitLab (developers still run bump locally before release).
- Changing OTA semver comparison logic or `device-app-version-single-source`.
- Bumping `modbus4android` or other library modules.

## Decisions

1. **Source file**: `app/build.gradle.kts` `defaultConfig` block — same file the app and Makefile already use for `versionName`.
2. **Display format**: `versionName+versionCode` (Flutter-style), e.g. `1.0.27+108`, not separate lines unless debugging.
3. **`versionCode` source**: Replace `getGitCount()` with a **literal integer** updated by `version-bump`. **Rationale**: build number must be intentional and monotonic for Play/store-style semantics; git count is opaque and unrelated to product version. **Alternative**: keep git count and only bump `versionName` — rejected because `+build` in VERSION would be meaningless.
4. **Implementation layout**: `scripts/make/app-version.sh` with subcommands `print`, `bump`, and shared validation; Makefile targets delegate to it. **Rationale**: keeps Makefile consistent with existing `scripts/make/pick-latest-firmware-bin.sh` pattern; easier to unit-test validation in bash.
5. **Update mechanism**: `sed` or `perl -pi` with anchored patterns for `versionName = "…"` and `versionCode = …` on the single `defaultConfig` occurrence. **Alternative**: Gradle property file — rejected to avoid a second source of truth.
6. **Validation regex** (conceptual): `^([0-9])\.([0-9])\.([0-9]{1,3})\+([1-9][0-9]*)$` then assert patch ≤ 100 and build ≥ 1.

## Risks / Trade-offs

- **[Risk] Accidental sed match on wrong line** → Mitigation: anchor patterns to `versionName` / `versionCode` in `defaultConfig`; script verifies post-write by re-parsing.
- **[Risk] `getGitCount()` removal breaks teams relying on auto build numbers** → Mitigation: document that `+build` must increment; first bump sets explicit baseline from current git count if desired.
- **[Risk] Patch `100` vs three-digit ambiguity** → Mitigation: explicit numeric check `patch <= 100` after parse.

## Migration Plan

1. Ship `scripts/make/app-version.sh` and Makefile targets.
2. One-time: run `make version` (may show `1.0.27+<gitCount>` before change), then `make version-bump VERSION=1.0.27+<desiredBuild>` to pin `versionCode` to the chosen build integer.
3. Remove or leave `getGitCount()` unused in `app/build.gradle.kts` (delete function if no other references).

## Open Questions

- None blocking implementation. If CI should echo version, add a later job step calling `make version` (out of scope here).
