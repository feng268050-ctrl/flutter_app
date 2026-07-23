## ADDED Requirements

### Requirement: Laser rising edge starts bounded zero-point detect task

When the device reports laser **OFF→ON** via cached `DeviceStatus`, the App SHALL start a zero-point detect task anchored at laser-on time `T₀`. The task SHALL schedule exactly **four** sample attempts at **`T₀ + 500ms`**, **`T₀ + 1000ms`**, **`T₀ + 1500ms`**, and **`T₀ + 2000ms`**. If laser turns OFF before a scheduled attempt fires, that attempt SHALL be cancelled. If laser turns ON again while a task is active, the App SHALL cancel the in-flight task and start a new task from the new `T₀`.

#### Scenario: Four samples on single laser-on

- **WHEN** laser transitions from OFF to ON and remains ON through `T₀ + 2000ms`
- **THEN** the system SHALL attempt zero-point detection at each of the four scheduled times
- **AND** SHALL NOT schedule additional samples after `T₀ + 2000ms` for that event

#### Scenario: Laser off cancels pending samples

- **WHEN** laser turns OFF before a scheduled sample time
- **THEN** pending scheduled samples for that task SHALL be cancelled
- **AND** partial results SHALL NOT be written to Modbus unless the product design explicitly completes early (default: no write)

#### Scenario: Re-trigger on second laser-on

- **WHEN** laser turns ON again while a zero-point task is still scheduled or running
- **THEN** the previous task SHALL be cancelled
- **AND** a new four-sample task SHALL start from the new laser-on time

### Requirement: Each sample uses I420 frame and zero-point native JNI

At each scheduled sample time, the App SHALL obtain a snapshot I420 frame from the production sub-stream (PR1) latest-frame holder, copy it to a direct buffer, and invoke `NativeBridge.nativeOpencvZeroPointDetectFromI420` on a background executor. The App SHALL NOT block Modbus polling or UI threads waiting for native completion.

#### Scenario: Successful native call

- **WHEN** a scheduled sample fires and a fresh I420 snapshot is available
- **THEN** the App SHALL call zero-point native detect with that frame
- **AND** SHALL parse the returned JSON on the worker thread

#### Scenario: No frame available at tick

- **WHEN** a scheduled sample fires but no I420 snapshot is available
- **THEN** that sample SHALL be skipped
- **AND** the task SHALL continue with remaining scheduled samples

### Requirement: Parse offset_x and compute UI correction with inverted sign

Native JSON SHALL expose at minimum `ok`, `code`, `offset_x`, and `offset_y`. For samples with **`ok == true`**, the App SHALL read **`offset_x`** (pixels, detected minus reference). UI zero correction uses **1 unit = 3px** with **+ = move zero right** and **− = move zero left**. The App SHALL compute per-sample UI delta as:

**`uiDelta = round(-offset_x / 3.0)`**

(JSON negative → UI increases; JSON positive → UI decreases.)

#### Scenario: Negative offset_x increases UI value

- **WHEN** a valid sample returns `offset_x = -9.0`
- **THEN** `uiDelta` SHALL be `+3`

#### Scenario: Positive offset_x decreases UI value

- **WHEN** a valid sample returns `offset_x = +12.0`
- **THEN** `uiDelta` SHALL be `-4`

### Requirement: Aggregate samples and update zeroPointCorrection with clamp

After the fourth sample attempt completes (success or skip), the App SHALL aggregate all valid samples from that task. If at least one valid sample exists, the App SHALL compute **`meanOffsetX`** as the arithmetic mean of valid `offset_x` values, derive **`uiDelta = round(-meanOffsetX / 3.0)`**, and set:

**`newZeroPointCorrection = clamp(currentZeroPointCorrection + uiDelta, -30, 30)`**

The App SHALL persist the new value and write Modbus register **0090H** using the existing Advanced Settings write path (`zeroPointCorrection × 10`). If no valid samples exist, the App SHALL leave `zeroPointCorrection` unchanged and SHALL NOT write 0090H for this task.

#### Scenario: Task applies incremental correction

- **WHEN** current `zeroPointCorrection` is `2` and valid samples yield `meanOffsetX = -9.0`
- **THEN** `uiDelta` SHALL be `+3`
- **AND** persisted correction SHALL become `5` before Modbus write

#### Scenario: Clamp at upper bound

- **WHEN** current value is `29` and aggregated `uiDelta` is `+5`
- **THEN** persisted correction SHALL be `30`

#### Scenario: All samples invalid

- **WHEN** all four attempts fail or are skipped
- **THEN** `zeroPointCorrection` SHALL remain unchanged
- **AND** Modbus 0090H SHALL not be updated by this task

### Requirement: Zero-point detect uses 500ms interval constant

The zero-point task schedule SHALL use **`AiFrameSamplingInterval.ZERO_POINT_ON_LASER`** with value **500 ms** for documentation and tests, aligned with other 500 ms AI Vision sampling constants.

#### Scenario: Constant value

- **WHEN** code reads `AiFrameSamplingInterval.ZERO_POINT_ON_LASER.getIntervalMs()`
- **THEN** the value SHALL be `500L`
