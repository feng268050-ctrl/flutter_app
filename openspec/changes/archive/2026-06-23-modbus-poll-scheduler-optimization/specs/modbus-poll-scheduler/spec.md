# modbus-poll-scheduler Specification

## Purpose

Enforce real 50ms minimum spacing between Modbus RTU commands for control-board cooling, drive device status/data polling via a 100ms refresh timer, and discard refresh attempts while the serial bus or an in-flight poll cycle is busy.

## ADDED Requirements

### Requirement: Serial command gate enforces minimum interval after command completion

The app SHALL enforce a single `COMMAND_INTERVAL_MS` with initial value **50** milliseconds between the **end** of one Modbus RTU command (request sent and response received or failure terminal) and the **start** of the next Modbus RTU command on the serial bus. The interval SHALL apply uniformly to poll reads, parameter writes, OTA writes, and boot self-check synchronous reads. The app SHALL NOT apply separate same-protocol vs different-protocol intervals (`SAME_PROTOCOL_INTERVAL` / `DIFF_PROTOCOL_INTERVAL`) on the `ModbusManagerRtu` path.

#### Scenario: Second command waits when previous ended recently

- **WHEN** a Modbus command completes at time T
- **AND** another Modbus command is submitted before `T + COMMAND_INTERVAL_MS`
- **THEN** the app SHALL delay the second command until at least `COMMAND_INTERVAL_MS` has elapsed since T
- **AND** SHALL then execute the second command

#### Scenario: No extra delay when interval already satisfied

- **WHEN** a Modbus command is submitted at time `T + COMMAND_INTERVAL_MS` or later after the previous command ended
- **THEN** the app SHALL execute the new command without additional gate sleep

#### Scenario: Mock mode skips gate sleep

- **WHEN** `ModbusConfig.isMock()` is true
- **THEN** the serial command gate SHALL NOT sleep
- **AND** Modbus stub reads/writes SHALL remain immediate

#### Scenario: OTA uses the same command interval

- **WHEN** controller firmware OTA performs Modbus write traffic
- **THEN** spacing between consecutive OTA Modbus commands SHALL use `COMMAND_INTERVAL_MS` (50ms)
- **AND** the app SHALL NOT switch to a separate shorter or longer upgrade-only interval profile

#### Scenario: No legacy dual-protocol interval on RTU path

- **WHEN** any Modbus RTU command is sent through `ModbusManagerRtu`
- **THEN** spacing SHALL be governed only by `COMMAND_INTERVAL_MS` via the serial command gate
- **AND** the app SHALL NOT use `DIFF_PROTOCOL_INTERVAL` or function-code-based interval selection

### Requirement: ModbusWorker send interval is disabled to avoid duplicate throttling

When opening the RTU serial port, the app SHALL set `ModbusWorker.setSendIntervalTime(0)` so that command spacing is enforced only by the app serial command gate.

#### Scenario: Open serial disables library interval

- **WHEN** `ModbusManagerRtu.openSerialPort` succeeds
- **THEN** `setSendIntervalTime(0)` SHALL have been applied
- **AND** command spacing SHALL rely on the app serial command gate

### Requirement: Device poll refresh timer attempts every 100 milliseconds

The app SHALL register a repeating poll refresh timer with period `POLL_TIMER_INTERVAL_MS` (**100** milliseconds). On each tick, the app SHALL **attempt** to start one poll cycle (read device status, then device data, then `finishPollCycle` side effects). The timer period SHALL NOT equal `COMMAND_INTERVAL_MS`; the two constants serve different purposes.

#### Scenario: Poll timer period is 100ms

- **WHEN** device status/data polling is active after Modbus is ready
- **THEN** the refresh timer SHALL fire every `POLL_TIMER_INTERVAL_MS` (100ms)
- **AND** each firing SHALL invoke the poll attempt entry point (not an unconditional cycle start)

#### Scenario: Poll starts when Modbus becomes ready

- **WHEN** Modbus initialization succeeds (or mock poll starts on emulator)
- **THEN** the 100ms refresh timer SHALL be started

### Requirement: Poll refresh attempts are discarded when bus or cycle is busy

When a refresh timer tick fires, the app SHALL start a poll cycle **only if** no poll cycle is in flight and the Modbus serial executor has no command in flight (including other reads/writes and gate wait tied to an active command). Otherwise the app SHALL **discard** that tick without queueing a deferred poll attempt.

#### Scenario: Discard when previous poll cycle still running

- **WHEN** a refresh timer tick fires
- **AND** a previous poll cycle has not yet completed device data handling and `finishPollCycle`
- **THEN** the app SHALL discard this tick
- **AND** SHALL NOT queue an additional poll cycle for this tick

#### Scenario: Discard when other Modbus command in flight

- **WHEN** a refresh timer tick fires
- **AND** a non-poll Modbus command (e.g., parameter write or OTA write) is executing on the serial executor
- **THEN** the app SHALL discard this tick
- **AND** SHALL NOT delay the in-flight command to start poll

#### Scenario: Poll cycle starts when idle

- **WHEN** a refresh timer tick fires
- **AND** no poll cycle is in flight
- **AND** no other Modbus command is in flight on the serial executor
- **THEN** the app SHALL start a poll cycle with chained status then data reads

#### Scenario: Status and data remain chained in one cycle

- **WHEN** a poll cycle starts and device status read succeeds
- **THEN** the app SHALL queue device data read in the same cycle subject to `COMMAND_INTERVAL_MS` gate spacing
- **AND** SHALL NOT start a second status read until the current cycle completes or fails terminally

### Requirement: OTA exclusive session pauses poll and blocks non-OTA Modbus traffic

When controller firmware OTA is active (`ModbusOtaExclusiveSession` or equivalent), the app SHALL pause the 100ms device poll refresh timer and SHALL NOT perform normal status+data poll cycles, parameter writes, engineer setting writes, or any Modbus **read** operations (including device status input register reads). Only OTA-whitelisted Modbus **writes** SHALL be permitted on the serial bus until `controllerUpgradeEnd` clears the session.

OTA-whitelisted traffic SHALL include only firmware upgrade related writes (`writeRegisters` / `writeRegistersCall`): file info, firmware data chunks, and upgrade end.

All OTA-whitelisted writes SHALL still enforce `COMMAND_INTERVAL_MS` (50ms) via the serial command gate.

#### Scenario: OTA pauses refresh timer and blocks parameter write

- **WHEN** controller OTA exclusive session becomes active
- **THEN** the 100ms poll refresh timer SHALL stop
- **AND** a non-OTA `writeRegisters` call (e.g., process parameter or device setting) SHALL fail fast without queueing on the serial executor

#### Scenario: OTA allows firmware chunk write at 50ms spacing

- **WHEN** OTA exclusive session is active
- **AND** `ControllerUpgradeHandler` sends a firmware data write
- **THEN** the write SHALL execute through the serial command gate with `COMMAND_INTERVAL_MS` spacing
- **AND** SHALL NOT be rejected as non-OTA traffic

#### Scenario: OTA end restores normal Modbus and poll timer

- **WHEN** controller upgrade completes through success, failure, or timeout handling and `controllerUpgradeEnd` runs
- **THEN** the OTA exclusive session SHALL clear
- **AND** the 100ms poll refresh timer SHALL restart
- **AND** non-OTA Modbus operations SHALL be permitted again subject to gate and discard rules

#### Scenario: Normal poll does not run during OTA

- **WHEN** OTA exclusive session is active
- **THEN** the app MUST NOT start a normal device status+data poll cycle (including via refresh timer tick)
- **AND** MUST NOT invoke `finishPollCycle` warn/alarm/LED side effects as part of a regular poll

#### Scenario: Modbus read rejected during OTA

- **WHEN** OTA exclusive session is active
- **AND** any caller attempts `readInputRegisters` (including device status)
- **THEN** the app SHALL reject the read fast without queueing on the serial executor

### Requirement: OTA firmware chunks are sequential Modbus writes with command gate spacing

During OTA exclusive session, after the firmware info write succeeds, the app SHALL transmit firmware data as a sequence of ordinary Modbus **write** frames (one packet per frame). The app SHALL advance file offset in application state after each successful data write and SHALL NOT read device status registers to determine the next offset or length.

Between consecutive OTA Modbus writes (info, each data chunk, and upgrade end), the app SHALL enforce `COMMAND_INTERVAL_MS` (50ms) via the serial command gate measured from the end of the previous write transaction.

#### Scenario: Next chunk after gate cooldown

- **WHEN** an OTA firmware data write completes successfully
- **AND** more file bytes remain
- **THEN** the app SHALL wait at least `COMMAND_INTERVAL_MS` after that write ends
- **AND** SHALL send the next firmware data write frame without an intervening Modbus read

#### Scenario: OTA uses same interval as normal traffic

- **WHEN** OTA firmware chunks are sent back-to-back
- **THEN** spacing between writes SHALL use `COMMAND_INTERVAL_MS` (50ms)
- **AND** SHALL NOT use a separate OTA-only interval constant

#### Scenario: OTA does not use upgradeHandler status poll path

- **WHEN** OTA exclusive session is active
- **THEN** the app SHALL NOT invoke `ControllerUpgradeHandler.upgradeHandler` from device status poll or Modbus status reads
- **AND** SHALL drive chunk transmission via the sequential write chain only

### Requirement: Debug observability for gate, discard, and cycle timing

In debug builds or when Modbus debug logging is enabled, the app SHALL log throttled metrics including gate wait time, poll tick discard reason, and poll cycle duration.

#### Scenario: Discard reason logged in debug

- **WHEN** a refresh timer tick is discarded
- **THEN** the app MAY emit a debug log identifying discard reason (`cycle_in_flight` or `bus_busy`) at a throttled rate

#### Scenario: Cycle metrics logged in debug

- **WHEN** a poll cycle completes in debug-enabled configuration
- **THEN** the app SHALL emit a throttled log line with cycle duration and inter-command gate wait
