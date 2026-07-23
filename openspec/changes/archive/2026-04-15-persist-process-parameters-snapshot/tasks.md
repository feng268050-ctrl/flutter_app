## 1. Snapshot State Foundation

- [x] 1.1 Identify the shared runtime state module that can own `processParameters` and define the canonical full snapshot schema.
- [x] 1.2 Implement a snapshot updater API that normalizes incoming Fast/Engineer parameter mutations into one complete in-memory snapshot.
- [x] 1.3 Add atomic/safe snapshot read access for message serialization to prevent partial reads during concurrent updates.

## 2. Mode Mutation Integration

- [x] 2.1 Wire Fast Mode parameter mutation flow to call the shared snapshot updater after each accepted parameter change.
- [x] 2.2 Wire Engineer Mode parameter mutation flow to call the shared snapshot updater after each accepted parameter change.
- [x] 2.3 Add tests proving both modes keep the snapshot complete and current across consecutive updates.

## 3. WebSocket Payload Integration

- [x] 3.1 Update `device.online` payload building to include `processParameters` from the shared snapshot.
- [x] 3.2 Update `command.stat_response` payload building to include `processParameters` from the shared snapshot.
- [x] 3.3 Add serialization and contract tests to verify both message types carry the same latest full snapshot.

## 4. Regression Safety

- [x] 4.1 Add edge-case tests for rapid parameter updates and missing/partial update inputs to ensure snapshot completeness rules hold.
- [x] 4.2 Verify existing fields in `device.online` and `command.stat_response` remain unchanged aside from additive `processParameters`.
- [x] 4.3 Run targeted integration tests and document any required follow-up for downstream consumers.
