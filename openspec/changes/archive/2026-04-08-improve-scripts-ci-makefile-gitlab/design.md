## Context

The Lws UI app is built as a **platform-signed** privileged APK for on-device WiFi and system integration. Validation already relies on **adb** and scripts such as `scripts/ci/wifi-smoke.sh`, but there is no single entry point for **build → install to priv-app → UI/instrumentation tests → CI scripts**. Teams need parity between **local** (`make`) and **GitLab** pipelines, with **signing** pulled from env (including optional `.env`) so keys are not hard-coded in Makefiles.

## Goals / Non-Goals

**Goals:**

- Provide a **Makefile** with documented targets: release build with `platform.jks`, **device preflight** (adb `device`, `/system` writable, priv-app permissions XML), **push APK** to `/system/priv-app/LwsUI/LwsUI.apk`, then **Gradle-connected UI tests** and **`scripts/ci/*.sh`** execution.
- Provide **`.gitlab-ci.yml`** with stages that mirror local flow: build job (artifacts), test job(s) that assume a runner with adb + attached device (or documented manual/trigger strategy).
- Load **keystore path and credentials** from **environment variables**, with optional **`.env`** at repo root for local use (gitignored or `.env.example` only in repo—no committed secrets).

**Non-Goals:**

- Replacing or rewriting existing product WiFi/UI behavior (only tooling and gates).
- Supporting emulator-only CI without a `device`-state adb target (user requires real device semantics).
- Managing GitLab runner installation or physical lab hardware (document expectations only).

## Decisions

1. **Makefile as the developer contract**  
   - **Choice**: Root `Makefile` delegates to `./gradlew` for compile/package and to small **bash** helpers under `scripts/ci/` (or `scripts/make/`) for adb-heavy steps.  
   - **Rationale**: Gradle already owns APK output; Make ties targets together without duplicating build logic.  
   - **Alternatives**: Pure Gradle tasks for adb (harder to read for ops); npm scripts (not idiomatic for Android here).

2. **Signing variables**  
   - **Choice**: Standard names such as `SIGNING_STORE_FILE`, `SIGNING_STORE_PASSWORD`, `SIGNING_KEY_ALIAS`, `SIGNING_KEY_PASSWORD`, defaulting store path to `./platform.jks` and alias/passwords to `android` when unset—matching the stated convention. Wire these into `app` signing config (or `signingConfigs.release`) via `gradle.properties` / `-P` / env read in `build.gradle.kts`.  
   - **Rationale**: CI can inject GitLab CI/CD variables; locally, `.env` can set the same names.  
   - **Alternatives**: Only interactive `gradle sign` (bad for CI); committed passwords (rejected).

3. **`.env` loading**  
   - **Choice**: Document `export` from `.env` before `make`, or use a **non-secret** pattern: `make` includes a line like `-include .env` only if the file uses `KEY=value` syntax Make can parse, **or** a wrapper script sources `.env` and execs make. Prefer **documented** `set -a; source .env; set +a` for shell users; for Make, pass through `$(shell …)` sparingly to avoid leaking values in logs—prefer **env vars already set** in CI.  
   - **Rationale**: Flexibility without mandating a new dependency; GitLab does not use `.env` files by default.

4. **Device preflight**  
   - **Choice**: One script (e.g. `scripts/ci/check-device.sh`) used by both Makefile and GitLab `before_script` / test job:  
     - `adb devices` → at least one line with state **`device`** (not `unauthorized`, `offline`, `emulator` if user excludes—user asked for type `device`; treat as adb state string `device`).  
     - **Writable `/system`**: e.g. `adb shell` with `su`/`root` as available on the test image—attempt create/remove under `/system` or check mount flags; **fail fast** if not writable.  
     - **Priv-app XML**: `adb shell` `cat` (or `test -f`) `/system/etc/permissions/privapp-permissions-com.lasercyber.lws.ui.xml` and **grep/validate** XML grants **`android.permission.NETWORK_SETTINGS`** for package **`com.lasercyber.lws.ui`** (minimum bar aligned with `docs/system-wifi-privileged-setup.md`).  
   - **Rationale**: Single source of truth for local vs CI; clear error messages.

5. **Install path**  
   - **Choice**: After build, `adb push` (or `adb shell` copy) built release APK to `/system/priv-app/LwsUI/LwsUI.apk`, then `chmod`/`chown` as required by image, **remount** if needed, **reboot** or **kill**/`pm install` strategy per device policy—**spec** locks path; **implementation** follows what the device root setup allows (document in script comments).  
   - **Rationale**: User specified exact path; priv-app layout must match.

6. **GitLab CI structure**  
   - **Choice**: Stages e.g. `build` → `test`. Build produces APK artifact. Test stage **needs** build artifact, runs preflight, install, `./gradlew :app:connected*AndroidTest` (or the variant used by the project), then `scripts/ci/wifi-smoke.sh` (and any future `scripts/ci/*.sh`). Use **`tags`** or **`resource_group`** if only one device exists; document that runners must have adb + device.  
   - **Alternatives**: Dind Android build (more complex); cloud device farms (out of scope).

## Risks / Trade-offs

- **[Risk] Privileged adb operations differ per device image** → **Mitigation**: Centralize in one script; clear stderr when `su`/`remount` fails; document required root/adb root.  
- **[Risk] `.env` accidentally committed** → **Mitigation**: `.gitignore` entry for `.env`; ship `.env.example` with variable names only.  
- **[Risk] GitLab shared runners lack hardware** → **Mitigation**: Mark test jobs `when: manual` or use specific runner tags; keep build job runnable everywhere.  
- **[Risk] XML permission check drifts from real platform XML** → **Mitigation**: Spec ties minimum to `NETWORK_SETTINGS`; extend list if manifest adds new signature permissions.

## Migration Plan

1. Add Makefile + scripts + Gradle signing hook; verify local `make build` / `make test` on a lab device.  
2. Add `.gitlab-ci.yml`; validate on a runner with device.  
3. Team updates internal docs to point to `make` / pipeline instead of one-off commands.

## Open Questions

- Whether test jobs should **fail skipped** when no runner tag is available, or use **manual** gates only (product/ops choice).  
- Exact **root remount** sequence for the target hardware (implementation detail in scripts).
