## Context

`lws_ai_daemon` is in-tree product code shipped under `/opt/hmi`, same family as the Flutter App. It was wired like third-party prebuilts:

1. Write `.lws-prebuilt` + binary under `prebuilt/ai/`.
2. `make build-ai` with stamp present → **skip compile**.
3. `rebuild-ai` / `FORCE=1` → wipe CMake tree + full rebuild (only way to pick up source edits).
4. `hmi_bundle_install_ai` requires **stamp AND** executable.

`make build-app` copies from `prebuilt/ai` when the daemon binary is acceptable. Stamp is redundant. Other repo targets already use `rebuild-*` / `FORCE=1` for forced refresh—AI should keep that habit, not invent `CLEAN=1`.

OpenCV/RKNN remain stamped third-party inputs. Static OpenCV abandoned (`archive/2026-08-07-lws-ai-static-opencv`).

## Goals / Non-Goals

**Goals:**

- Daily: edit `native/lws_ai` → `make build-ai` → `make build-app` / `push-app`.
- Incremental CMake on plain `build-ai`.
- `rebuild-ai` / `FORCE=1` = wipe + full rebuild (aligned with other commands).
- Bundle on binary presence, not `.lws-prebuilt`.

**Non-Goals:**

- A separate `CLEAN=` flag for AI.
- Auto-invoking `build-ai` from `build-app`.
- Changing MediaMTX/OpenCV stamp conventions.
- Static OpenCV / ccache / Docker cold-start as required work.

## Decisions

### D0 — First-party build + package on artifacts

- **Build:** `make build-ai` always incremental compile/restage (not stamp-lock).
- **Package:** `hmi_bundle_install_ai` when `prebuilt/ai/linux-arm64/lws_ai_daemon` is executable. **No stamp check.**

### D1 — Keep CMake build tree on plain `build-ai`

Remove unconditional `rm -rf "$BUILD_DIR/cmake"` from the default path.

### D2 — `rebuild-ai` / `FORCE=1` wipes the build tree

Same operator habit as other `rebuild-*` / `FORCE=1` targets: delete `$BUILD_DIR/cmake`, then configure + build + restage. Use when toolchain/OpenCV inputs change oddly or the cache is corrupt—not for ordinary source edits.

**Alternatives considered:** `CLEAN=1` — rejected; duplicates FORCE/rebuild vocabulary already used repo-wide.

### D3 — Configure fingerprint; auto-wipe on mismatch

Fingerprint toolchain + OpenCV/RKNN paths + key `-D` options. On mismatch → same wipe path as `FORCE=1` for that run.

### D4 — Invocation semantics

| Invocation | Behavior |
|------------|----------|
| `make build-ai` | Incremental cmake + restage. Daily command. |
| `make rebuild-ai` / `FORCE=1 make build-ai` | Wipe cmake dir, then full configure + build + restage. |

Keep Makefile `rebuild-ai: FORCE=1 bash scripts/build-ai.sh`.

### D5 — Stop writing AI `.lws-prebuilt`

Prefer no `prebuilt_stamp` for AI; fix manifest helpers if needed. Do not reintroduce stamp as a gate.

### D6 — Staging content unchanged

Daemon + `libopencv_*.so*`; never stage `librknnrt.so`.

## Risks / Trade-offs

- **[Risk] Half-written `prebuilt/ai`** → stage carefully; binary `-x` is the gate.
- **[Risk] Operators keep using `rebuild-ai` for every edit** → docs: daily is `build-ai`; rebuild is force-clean only.
- **Trade-off:** `build-runtime-deps` may cheaply touch AI instead of stamp skip — correct for first-party.

## Migration Plan

1. Land script + bundle + docs.
2. Leftover `.lws-prebuilt` ignored; safe to delete.
3. Rollback: restore stamp skip + always-wipe-on-FORCE semantics mixed with skip (old behavior).

## Open Questions

- None blocking.
