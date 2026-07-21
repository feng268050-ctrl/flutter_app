## Context

`BootSelfCheckCoordinator` already gates with `BootSelfCheckGate.isCompletedInProcess` and Misc `showStartupSelfCheck`. That matches the archived `product-boot-self-check` “once per process” requirement and lws-ui parity at the time. On the appliance, operators and developers restart `hmi.service` often (`push-app`, debug, crash recovery); each restart is a new process, so the Frost dialog reappears and feels like a bug relative to “开机自检”.

`/run/hmi` is already created by `hmi-launch.sh` (tmpfs under `/run`, cleared on reboot). Prefer that over `/var/lib/hmi` so markers do not survive reboot without extra cleanup.

## Goals / Non-Goals

**Goals:**

- Show startup self-check at most **once per system boot**, on the first Home entry when the Misc preference is enabled.
- Skip the dialog on later HMI process starts within the same boot (restart, crash loop, hot-push).
- Keep process-local gate so navigating away from Home and back in one process still skips.
- Preserve preference-off / “don’t show again” behavior and non-blocking Home first paint.

**Non-Goals:**

- Changing check items, Modbus/camera evaluation, dialog UI, or auto-dismiss timing.
- Showing self-check on demand from Settings (no “run now” button in this change).
- Persisting last-run results across boots for audit/history.
- Overlay/systemd changes beyond relying on existing `/run/hmi`.

## Decisions

### D1 — Boot-scoped marker under `/run/hmi`

**Choice:** When self-check is considered “consumed” for this boot (dialog finished, or preference disabled so we mark complete for gate purposes), write a marker file e.g. `/run/hmi/boot-self-check-done` (empty or single-line stamp). On Home entry, if the marker exists, treat as already completed for this boot and skip the dialog.

**Alternatives considered:**

| Option | Why not |
|--------|---------|
| Keep only in-process bool | Does not survive `hmi.service` restart — the reported bug. |
| Persist under `/var/lib/hmi` + store boot_id | Works, but needs comparing `/proc/sys/kernel/random/boot_id` and never auto-clears without that compare; more code for same effect as tmpfs. |
| Kernel boot_id only in memory | Lost on process exit; same as today. |
| systemd unit `ConditionPathExists=!…` | Would skip launching HMI entirely or need a wrapper; wrong layer for a Flutter overlay. |

### D2 — When to create the marker

**Choice:** Create/update the marker in the same paths that today call `BootSelfCheckGate.markCompletedInProcess()` after a run finishes **or** when preference is disabled at Home entry (skip path). That way a disabled preference does not leave an open “first show” slot for the next restart within the same boot if the operator later re-enables the toggle mid-boot—see D3.

**Refinement (D3):** If preference is disabled at first Home entry, mark boot consumed (write marker + in-process complete) so mid-boot re-enable does **not** surprise-show after a restart. If preference is re-enabled mid-boot **without** restarting HMI, in-process gate already completed → still skip until next reboot. Acceptable: “don’t show again” and Misc off mean no self-check until next power cycle even if toggled back on before reboot. Document in tasks/tests.

### D3 — Gate API shape

**Choice:** Extend `BootSelfCheckGate` (or a thin `BootSelfCheckBootMarker` helper used by the gate/coordinator) with:

- `hasCompletedThisBoot` — true if marker exists (injectable path for tests)
- `markCompletedThisBoot()` — write marker + set in-process flag
- Keep `isCompletedInProcess` for fast path; coordinator checks boot marker **or** in-process before starting

Tests use a temp directory instead of `/run/hmi`.

### D4 — Failure to write marker

**Choice:** Soft-fail: log and continue. If write fails, behavior degrades to today’s once-per-process (may re-show on next HMI restart). Do not crash Home.

### D5 — Host / stub

**Choice:** On non-Linux or missing `/run/hmi`, `mkdir` best-effort then write; if still failing, soft-fail as D4. Widget/unit tests never touch real `/run`.

## Risks / Trade-offs

- **[Risk] Mid-boot Misc re-enable does not show self-check until reboot** → Mitigation: intentional (D3); document in spec scenario.
- **[Risk] Marker write fails → re-show on restart** → Mitigation: soft-fail + debug log; rare on appliance with `/run/hmi` already mkdir’d.
- **[Risk] Manual `rm /run/hmi/boot-self-check-done` re-triggers** → Acceptable for factory/debug; not a product path.
- **[Trade-off] Not using boot_id** → Simpler; relies on tmpfs semantics. If someone mounts persistent storage over `/run/hmi` (they must not), marker would stick — out of product config.

## Migration Plan

- App-only change: `make build-app` + `make push-app` (or bake into rootfs for release).
- No GPT / overlay migration. Existing boards already have `/run` tmpfs and `mkdir -p /run/hmi` in launch.
- Rollback: revert App; delete marker harmless.

## Open Questions

- None blocking; marker filename `/run/hmi/boot-self-check-done` is the default unless implementation prefers a short name already used elsewhere.
