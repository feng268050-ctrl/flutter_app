## MODIFIED Requirements

### Requirement: Laser rising edge starts bounded zero-point detect task

When the device reports laser **OFF→ON** via cached `DeviceStatus`, the App SHALL start a zero-point detect **round** anchored at laser-on time `T₀`. While laser remains ON, the App SHALL perform **continuous PR1-driven** zero-point detect samples: the first attempt MUST be eligible on the **first acceptable PR1 I420 frame** after `T₀` (no mandatory `T₀ + 500ms` delay). Subsequent attempts SHALL respect the zero-point sampling gate (`ZERO_POINT_ON_LASER`, **500ms** in normal mode, or **100ms** burst interval when burst mode is active). There SHALL be **no fixed maximum sample count** per laser-on event. When laser turns **OFF**, the App SHALL finalize that round (aggregate valid samples and apply correction per existing cluster-reducer rules). If laser turns ON again while a round is active, the App SHALL cancel the in-flight round and start a new round from the new `T₀`.

#### Scenario: First sample on first PR1 frame

- **WHEN** laser transitions from OFF to ON
- **AND** PR1 streaming delivers the first I420 frame at `T₀ + Δ` where `Δ` may be less than 500ms
- **THEN** the system SHALL attempt zero-point detection on that frame (subject to gate and busy rules)
- **AND** SHALL NOT defer the first attempt solely until `T₀ + 500ms`

#### Scenario: Continuous sampling while laser on

- **WHEN** laser remains ON and PR1 frames continue
- **THEN** the system SHALL keep attempting zero-point detection at the configured gate interval
- **AND** SHALL NOT stop after a fixed fourth sample

#### Scenario: Laser off finalizes round

- **WHEN** laser turns OFF after one or more sample attempts in the current round
- **THEN** the App SHALL run cluster aggregation on valid samples from that round
- **AND** SHALL apply or skip Modbus write per existing tolerance and reducer rules

#### Scenario: Laser off cancels further sampling

- **WHEN** laser turns OFF
- **THEN** no further zero-point samples SHALL run for that round

#### Scenario: Re-trigger on second laser-on

- **WHEN** laser turns ON again while a zero-point round is still active
- **THEN** the previous round SHALL be cancelled without finalize (or finalize only if product explicitly completes on OFF—default: discard partial round on ON re-trigger before new round starts)
- **AND** a new round SHALL start from the new laser-on time

### Requirement: Each sample uses I420 frame and zero-point native JNI

At each PR1-driven sample opportunity while laser is ON, the App SHALL obtain a snapshot I420 frame from the production sub-stream (PR1) latest-frame holder, copy it to a direct buffer, and invoke `NativeBridge.nativeOpencvZeroPointDetectFromI420` on a background executor. The App SHALL NOT block Modbus polling or UI threads waiting for native completion.

#### Scenario: Successful native call

- **WHEN** a PR1-driven sample is accepted and a fresh I420 snapshot is available
- **THEN** the App SHALL call zero-point native detect with that frame
- **AND** SHALL parse the returned JSON on the worker thread

#### Scenario: No frame available

- **WHEN** a sample opportunity occurs but no I420 snapshot is available
- **THEN** that sample SHALL be skipped
- **AND** the round SHALL continue on subsequent PR1 frames while laser remains ON

### Requirement: Aggregate samples and update zeroPointCorrection with clamp

When laser turns **OFF** for the current zero-point round, the App SHALL collect all native-valid (`ok == true`) samples from that round into `ZeroPointDetectClusterReducer` as **one detection round**. The reducer SHALL apply cluster selection (3px tolerance, largest cluster, representative nearest cluster center) with priority over round-anchor filtering (10px from first valid sample), per `zero-point-detect-cluster-filter`.

If the reducer returns a representative sample, the App SHALL set **`meanOffsetX`** and **`meanOffsetY`** to that representative's offsets (not the arithmetic mean of the raw list), derive **`uiDelta = round(-meanOffsetX / 3.0)`**, and set:

**`newZeroPointCorrection = clamp(currentZeroPointCorrection + uiDelta, -30, 30)`**

The App SHALL persist the new value and write Modbus register **0090H** using the existing Advanced Settings write path (`zeroPointCorrection × 10`). If the reducer returns no representative (no valid samples or empty round), the App SHALL leave `zeroPointCorrection` unchanged and SHALL NOT write 0090H for this round.

#### Scenario: Round applies correction from cluster representative on laser off

- **WHEN** laser turns OFF and valid samples in the round include outliers but the reducer representative yields `offset_x = -9.0`, `offset_y = 0.0`
- **THEN** `meanOffsetX` SHALL be `-9.0`
- **AND** `uiDelta` SHALL be `+3`
- **AND** persisted correction SHALL be updated before Modbus write when tolerance allows

#### Scenario: All samples invalid on laser off

- **WHEN** laser turns OFF and no valid samples exist in the round (or reducer returns no representative)
- **THEN** `zeroPointCorrection` SHALL remain unchanged
- **AND** Modbus 0090H SHALL not be updated for this round

#### Scenario: Cluster reducer invoked once per round on laser off

- **WHEN** laser turns OFF for `eventId=N`
- **THEN** the App SHALL invoke the cluster reducer exactly once with all valid samples from that round
- **AND** SHALL NOT arithmetic-mean the raw offset lists before correction mapping
