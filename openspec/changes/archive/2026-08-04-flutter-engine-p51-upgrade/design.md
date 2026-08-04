## Context

P5.1 in `docs/flutter-linux-hmi-plan.md` (and README dependency table) calls for upgrading **Flutter SDK + flutter-engine + flutter-embedded-linux** from the **3.24** generation to the **3.41** (2026) generation. Current git-tracked pins:

| Pin | Value |
|-----|--------|
| `overlay/buildroot/flutter-sdk.version` | **3.24.4** |
| `overlay/buildroot/flutter-engine.version` | **3.24.4** |
| `overlay/buildroot/flutter-embedded-linux.version` | **db49896cf2** |
| Overlay `.mk` | matching 3.24.4 / db49896cf2 |
| Agent rule | `.cursor/rules/flutter-3.24-api.mdc` — App API = 3.24.4 only |

Build flow (unchanged shape):

1. `make fetch-flutter-sdk` → gitignored `flutter-sdk/`
2. `make fetch-flutter-engine` → `.cache/` tarball (NAS/HTTP/gclient)
3. `make build-flutter-engine` → `prebuilt/flutter-engine/<ver>/arm64-<mode>/`
4. `make build-flutter-embedded-linux` → `prebuilt/flutter-embedded-linux/<tag>/` (+ `.lws-gstreamer-video-player`)
5. BR packages install prebuilts into rootfs; `make build-app` AOT-compiles with matching `gen_snapshot` / SDK

Display stack remains **Weston + flutter-wayland-client** (`embedder-migration-plan.md`). Engine upgrade is the primary lever if vsync/Animator limits remain after Weston tuning.

Stable tip observed at proposal time: Flutter **3.41.9** (2026-04-30) with Dart **3.11.5**. Later 3.41.x hotfixes supersede when available. Flutter **3.44+** exists on docs marketing; **P5.1 scope stays on the 3.41 line** unless a spike proves eLinux cannot track 3.41 and product explicitly retargets.

## Goals / Non-Goals

**Goals:**

- Ship the triplet at **Flutter ≥ 3.41.0**, prefer newest **3.41.x** tip (e.g. 3.41.9+).
- Keep Weston + eLinux Wayland client + GStreamer video plugin path working on ynh960.
- Migrate App/packages to the new Dart/Flutter API; update agent rules and hardcoded 3.24.4 docs/specs.
- Preserve `make debug-app` / Custom Device workflow on the new pin.
- Record acceptance: boot Home, Settings camera preview, push-app, debug attach.

**Non-Goals:**

- P5.0 Android APK / YNHAPI.
- Switching embedder (flutter-pi / flutter-auto).
- Mandating Impeller on eLinux (community eLinux historically Skia; Impeller only if spike + product want it).
- Fixing unrelated OS CVEs in this change (coordinate rebuilds only).
- Jumping past 3.41 to 3.44+ in the first landing (optional follow-up change).

## Decisions

### D1 — Triplet lockstep; never skew SDK vs engine vs eLinux

`flutter-sdk.version`, `flutter-engine.version`, and the eLinux commit/tag MUST move together. `hmi-bundle-common.sh` already enforces SDK stamp vs `ENGINE_VER`. eLinux MUST be rebuilt against the new `libflutter_engine.so` / `flutter_embedder.h`.

**Alternative:** bump SDK only for host analyze — **rejected** (AOT/device mismatch).

### D2 — Target version: **3.41.x tip** (floor 3.41.0)

At implement time, lock the newest published **stable 3.41.x** (proposal baseline **3.41.9**). Do not land mid-series older than the then-current tip without a written reason.

**Fallback:** If eLinux / embedder API cannot support 3.41, spike the highest buildable 3.3x/3.4x that eLinux upstream supports and open a plan amendment — do not silently stay on 3.24.4.

### D3 — eLinux source pin strategy

1. Prefer an upstream **flutter-embedded-linux** (Sony → flutter-elinux org or product fork) commit that documents Flutter **3.41** engine compatibility.
2. If upstream lags, carry a **product fork / overlay patches** on top of current `db49896cf2` lineage to match 3.41 embedder headers — same pattern as other overlay BR packages.
3. Update `flutter-embedded-linux.version` to the new short hash/tag used as prebuilt directory name.

### D4 — App API migration is in-scope

Treat P5.1 as a **framework upgrade**, not only binary swap:

- Run `flutter analyze` / build under the new SDK; fix breakages (`DropdownButtonFormField` `value`→`initialValue` and similar).
- Replace `.cursor/rules/flutter-3.24-api.mdc` with a **3.41.x** pin rule (or rename file and globs).
- Path packages (`cyber_ui`, `cyber_ime`, `cyber_hal`, …) MUST analyze clean on the new SDK.

### D5 — Prebuilt rebuild contract

Order (typical):

1. Update version files + `.mk`
2. `make apply-overlay`
3. `make fetch-flutter-sdk`
4. `make fetch-flutter-engine` / `FORCE=1 make build-flutter-engine`
5. Ensure GStreamer staging `.pc` present (current or after `gstreamer-security-upgrade`)
6. `FORCE=1 make build-flutter-embedded-linux`
7. `make build-app` (+ `flutter analyze` / tests)
8. `make build-rootfs` → `make upgrade` (and/or `push-app` for App-only once rootfs engine matches)

`check-prebuilt` MUST fail closed if stamps missing.

### D6 — Rendering backend

Default: keep **Skia** path used by current eLinux Wayland client. Impeller is **opt-in spike only**; do not block P5.1 on Impeller.

### D7 — Roadmap / docs hygiene

When acceptance passes: update `docs/flutter-linux-hmi-plan.md` P5.1 status ✅, README P5.1 row, AGENTS rebuild notes if targets change, and fix stale “37bd977” wording in specs (current tree already uses `db49896cf2`).

### D8 — Sequencing with other OpenSpec security changes

Independent of OpenSSL/BlueZ/kernel. **Shared touchpoint** with `gstreamer-security-upgrade`: eLinux GStreamer video plugin rebuild. Prefer: GStreamer tip stable in staging **before** final eLinux link, or rebuild eLinux twice if both land close together.

## Risks / Trade-offs

- **[Risk] eLinux upstream abandoned / stuck below 3.41** → Mitigation: D3 product fork/patches; fallback version with plan note.
- **[Risk] Large Dart API churn in CyberUI / App** → Mitigation: incremental analyze+fix; keep visual smoke checklist.
- **[Risk] Embedder ABI / ICU path break → blank screen** → Mitigation: verify `icudtl.dat` + `libflutter_engine.so` versions; journal + `hmi.service`.
- **[Risk] debug-app / VM Service regress** → Mitigation: host-debug-hmi acceptance tasks on new pin.
- **[Risk] Cache/NAS still serves 3.24.4 engine tarball** → Mitigation: new version dir keys; `refetch` / publish new cache objects.
- **[Trade-off] 3.41 vs jumping to 3.44+** → Prefer plan-aligned 3.41.x first; later major is a follow-up change.

## Migration Plan

1. Spike eLinux + engine 3.41.x on Docker BR / prebuilt.
2. Land pin + App API fixes on a branch; device smoke.
3. A/B upgrade rootfs; keep previous letter for rollback.
4. Update roadmap status and agent API rule.
5. Rollback: restore 3.24.4 pins + prior prebuilt stamps + previous rootfs letter / reflash.

## Open Questions

- Exact eLinux upstream commit/tag that claims 3.41 support (resolve in task 1.x spike).
- Whether product wants a same-PR jump to **>3.41** if eLinux already tracks newer (default **no**).
- Impeller interest on Mali/ynh960 (default **no** for P5.1).
- Whether P5.0 Android should intentionally stay on a different Flutter pin (out of scope; document if dual-pin appears).
