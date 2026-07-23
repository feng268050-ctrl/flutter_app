## MODIFIED Requirements

### Requirement: Laser rising edge starts bounded zero-point detect task

When the device reports laser **OFF→ON** via cached `DeviceStatus` and `zeroPointOffsetDetectionEnabled` is true, the App SHALL start a zero-point detect **round** anchored at laser-on time `T₀`. While laser remains ON, the App SHALL perform **continuous PR1-driven** zero-point detect samples: the first attempt MUST be eligible on the **first acceptable PR1 I420 frame** after `T₀` (no mandatory `T₀ + 500ms` delay). Subsequent attempts SHALL respect the zero-point sampling gate (`ZERO_POINT_ON_LASER`, **500ms** in normal mode, or **100ms** burst interval when burst mode is active). There SHALL be **no fixed maximum sample count** per laser-on event. When laser turns **OFF**, the App SHALL finalize that round (aggregate valid samples and apply correction per existing cluster-reducer rules). If laser turns ON again while a round is active, the App SHALL cancel the in-flight round and start a new round from the new `T₀`.

When `zeroPointOffsetDetectionEnabled` is false, the App SHALL NOT start a zero-point detect round on laser rising edge and SHALL NOT perform PR1-driven zero-point samples for that laser-on session.

#### Scenario: First sample on first PR1 frame

- **WHEN** laser transitions from OFF to ON
- **AND** `zeroPointOffsetDetectionEnabled` is true
- **AND** PR1 streaming delivers the first I420 frame at `T₀ + Δ` where `Δ` may be less than 500ms
- **THEN** the system SHALL attempt zero-point detection on that frame (subject to gate and busy rules)
- **AND** SHALL NOT defer the first attempt solely until `T₀ + 500ms`

#### Scenario: Continuous sampling while laser on

- **WHEN** laser remains ON and PR1 frames continue
- **AND** `zeroPointOffsetDetectionEnabled` is true
- **THEN** the system SHALL keep attempting zero-point detection at the configured gate interval
- **AND** SHALL NOT stop after a fixed fourth sample

#### Scenario: Laser off finalizes round

- **WHEN** laser turns OFF after one or more sample attempts in the current round
- **AND** `zeroPointOffsetDetectionEnabled` was true for that round
- **THEN** the App SHALL run cluster aggregation on valid samples from that round
- **AND** SHALL apply or skip Modbus write per existing tolerance and reducer rules

#### Scenario: Laser off cancels further sampling

- **WHEN** laser turns OFF
- **THEN** no further zero-point samples SHALL run for that round

#### Scenario: Re-trigger on second laser-on

- **WHEN** laser turns ON again while a zero-point round is still active
- **AND** `zeroPointOffsetDetectionEnabled` is true
- **THEN** the previous round SHALL be cancelled without finalize (or finalize only if product explicitly completes on OFF—default: discard partial round on ON re-trigger before new round starts)
- **AND** a new round SHALL start from the new laser-on time

#### Scenario: Toggle off skips entire laser-on round

- **WHEN** `zeroPointOffsetDetectionEnabled` is false
- **AND** laser transitions from OFF to ON
- **THEN** the App SHALL NOT start a zero-point detect round
- **AND** SHALL NOT sample PR1 frames for zero-point detect while laser remains ON
- **AND** SHALL NOT finalize or write 0090H when laser turns OFF for that session
