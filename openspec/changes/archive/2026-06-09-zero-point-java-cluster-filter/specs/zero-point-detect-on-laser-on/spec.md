## MODIFIED Requirements

### Requirement: Aggregate samples and update zeroPointCorrection with clamp

After the fourth sample attempt completes (success or skip), the App SHALL collect all native-valid (`ok == true`) samples from that laser-on task into `ZeroPointDetectClusterReducer` as **one detection round**. The reducer SHALL apply cluster selection (3px tolerance, largest cluster, representative nearest cluster center) with priority over round-anchor filtering (10px from first valid sample), per `zero-point-detect-cluster-filter`.

If the reducer returns a representative sample, the App SHALL set **`meanOffsetX`** and **`meanOffsetY`** to that representative's offsets (not the arithmetic mean of the raw list), derive **`uiDelta = round(-meanOffsetX / 3.0)`**, and set:

**`newZeroPointCorrection = clamp(currentZeroPointCorrection + uiDelta, -30, 30)`**

The App SHALL persist the new value and write Modbus register **0090H** using the existing Advanced Settings write path (`zeroPointCorrection × 10`). If the reducer returns no representative (no valid samples or empty round), the App SHALL leave `zeroPointCorrection` unchanged and SHALL NOT write 0090H for this task.

#### Scenario: Task applies incremental correction from cluster representative

- **WHEN** current `zeroPointCorrection` is `2` and valid samples include outliers but the reducer representative yields `offset_x = -9.0`, `offset_y = 0.0`
- **THEN** `meanOffsetX` SHALL be `-9.0`
- **AND** `uiDelta` SHALL be `+3`
- **AND** persisted correction SHALL become `5` before Modbus write

#### Scenario: Clamp at upper bound

- **WHEN** current value is `29` and aggregated `uiDelta` is `+5`
- **THEN** persisted correction SHALL be `30`

#### Scenario: All samples invalid or reducer empty

- **WHEN** all four attempts fail or are skipped, or the reducer returns no representative
- **THEN** `zeroPointCorrection` SHALL remain unchanged
- **AND** Modbus 0090H SHALL not be updated by this task

#### Scenario: Cluster reducer invoked once per task

- **WHEN** the fourth sample attempt completes for `eventId=N`
- **THEN** the App SHALL invoke the cluster reducer exactly once with all valid samples from that task
- **AND** SHALL NOT arithmetic-mean the raw offset lists before correction mapping
