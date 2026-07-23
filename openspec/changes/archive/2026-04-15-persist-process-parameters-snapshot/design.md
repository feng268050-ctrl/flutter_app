## Context

Fast Mode and Engineer Mode both mutate process parameters over time, but outbound status messages currently depend on whichever parameter values are available at send time rather than a guaranteed full snapshot. This causes inconsistency risk between `device.online` and `command.stat_response`, especially under rapid updates or partially applied parameter writes.

The change must provide a single authoritative in-memory snapshot that is updated in real time on every process-parameter mutation in these two modes, then reused by websocket message builders to publish a complete and consistent `processParameters` object.

## Goals / Non-Goals

**Goals:**
- Keep a complete in-memory process-parameter snapshot synchronized with Fast Mode and Engineer Mode parameter updates.
- Ensure `device.online` and `command.stat_response` both include `processParameters` from the same live snapshot source.
- Define deterministic merge/replace rules for parameter updates so snapshot completeness is maintained.
- Keep wire compatibility by making the new field additive and preserving existing message fields.

**Non-Goals:**
- Redesigning parameter semantics or introducing new parameter types.
- Persisting the snapshot to disk or restoring it across app restart.
- Changing message trigger timing for `device.online` or `command.stat_response`.

## Decisions

1. **Introduce a dedicated snapshot state holder**
   - Decision: maintain an in-memory `processParameters` snapshot in the shared device runtime state accessed by both mode update handlers and websocket serializers.
   - Rationale: avoids duplicated reconstruction logic and guarantees one source of truth for outbound payloads.
   - Alternative considered: recompute parameters on each send from scattered state; rejected due to race/incompleteness risk and repeated transformation cost.

2. **Update snapshot on every mode-level parameter mutation**
   - Decision: Fast Mode and Engineer Mode mutation paths MUST feed a common snapshot update API immediately after validating an incoming parameter change.
   - Rationale: guarantees real-time behavior and consistent contract regardless of mode-specific code paths.
   - Alternative considered: periodic polling-based sync; rejected because it introduces lag and can miss transient intermediate updates.

3. **Use full-snapshot serialization with atomic read**
   - Decision: websocket emitters read a single atomic view of snapshot data and serialize it under `processParameters` for both message types.
   - Rationale: ensures `device.online` and `command.stat_response` cannot observe different partial states during concurrent writes.
   - Alternative considered: direct map reference sharing; rejected because mutable references can leak mid-update state.

4. **Treat missing fields as explicit unknown/defaults in snapshot normalization**
   - Decision: snapshot update API normalizes absent values to agreed defaults (or retained prior values when update semantics are patch-based), so serialized snapshot remains structurally complete.
   - Rationale: complete payload shape is a core requirement of this change.
   - Alternative considered: sparse serialization of only updated keys; rejected because downstream expects full snapshot.

## Risks / Trade-offs

- **[Risk] Concurrency between parameter writes and websocket sends could expose stale values** -> **Mitigation**: use synchronized/atomic snapshot replace and immutable copy on read.
- **[Risk] Snapshot shape drift from canonical parameter schema** -> **Mitigation**: centralize normalization and add schema-level unit tests for full field coverage.
- **[Risk] Additional memory usage for full snapshot copy** -> **Mitigation**: store one normalized object and use cheap immutable copy/serialization strategy.
- **[Risk] Incomplete adoption if one mode bypasses update API** -> **Mitigation**: enforce both mode flows to call the shared updater and cover with integration tests.
