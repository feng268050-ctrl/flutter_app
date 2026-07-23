## Context

`WarnInfoFragment` and `fragment_warn_info.xml` currently bind alarm checkboxes directly to `DeviceStatus`/`DeviceData` alarm fields. When the lower controller is not connected, cache values can be null or default-initialized, and the current expressions evaluate to "normal" (green checked), which is misleading in an offline state.

The change needs to preserve existing alarm semantics after real status polling begins, while preventing false healthy indicators before data readiness.

## Goals / Non-Goals

**Goals:**
- Ensure Alarm Information checkboxes do not display healthy/normal state before valid controller status is available.
- Keep online behavior unchanged after real `DEVICE_STATUS_KEY` and `DEVICE_DATA_KEY` updates arrive.
- Keep scope local to Alarm Information rendering and readiness gating.

**Non-Goals:**
- No changes to Modbus polling frequency or transport startup behavior.
- No redesign of Alarm Logs persistence/query behavior.
- No new backend/device protocol fields.

## Decisions

1. **Use UI readiness gating in `WarnInfoFragment`**
   - Add boolean readiness flags for status/data (`statusReady`, `dataReady`) and expose them to data binding.
   - Rationale: smallest change that is local to current screen and does not alter shared status models.
   - Alternative considered: add global "device connected" bit in cache and reuse everywhere. Rejected for this change because it broadens scope and adds cross-screen dependency.

2. **Guard checkbox checked expressions by readiness**
   - In `fragment_warn_info.xml`, change checked expressions from direct alarm negation to conditional expressions that return false when not ready.
   - Rationale: guarantees offline state cannot appear healthy even if object defaults are present.
   - Alternative considered: hide checkbox views when offline. Rejected to avoid layout jumps and preserve stable UI structure.

3. **Preserve existing alarm evaluation logic when ready**
   - Existing alarm field interpretation (`isXxxAlarm`) and value/error combinations remain unchanged once readiness is true.
   - Rationale: avoids functional regression for connected devices.

## Risks / Trade-offs

- **[Risk] Readiness may briefly stay false during startup and show unchecked states** -> **Mitigation:** Acceptable transient state because it is safer than showing false healthy status; readiness flips on first valid cache update.
- **[Risk] Some tiles rely on both status and data; partial readiness handling could diverge** -> **Mitigation:** Use `statusReady && dataReady` for mixed status+data expressions.
- **[Trade-off] Local readiness flags duplicate potential global connection state** -> **Mitigation:** Keep scoped fix now; revisit shared connectivity abstraction in a separate capability if needed.

## Migration Plan

1. Update `WarnInfoFragment` to track and bind readiness booleans.
2. Update `fragment_warn_info.xml` checked expressions to gate on readiness.
3. Verify:
   - offline (no lower controller) -> no green checked "normal" states
   - online with valid status/data -> behavior matches existing alarm logic.
4. Rollback strategy: revert `WarnInfoFragment` + `fragment_warn_info.xml` deltas if any regression appears.

## Open Questions

- Should offline state eventually show an explicit "Not Connected" badge/text in each tile instead of only unchecked status?
- Should the same readiness gating be applied to other monitor tabs with normal/alarm check marks?
