## ADDED Requirements

### Requirement: Modbus RTU opens Linux serial port

The HMI Modbus client SHALL open Modbus RTU on Linux device **`/dev/ttyS5`** using `flutter_libserialport` (or an equivalent serial backend compatible with flutter-pi ARM64). Serial framing parameters SHALL match lws-ui Modbus RTU configuration for the product (baud, data bits, parity, stop bits).

#### Scenario: Port open succeeds when device node exists

- **WHEN** `/dev/ttyS5` is present and the HMI process has permission to open it
- **THEN** the Modbus client initializes without throwing an unhandled error to the UI isolate

#### Scenario: Port missing does not crash the app

- **WHEN** `/dev/ttyS5` is absent or open fails
- **THEN** the app remains running and device-info Modbus fields resolve to display value `-`

### Requirement: Device-info register map matches lws-ui

The client SHALL use the same Modbus register addresses as lws-ui for P2 device-info reads:

| Display field | Address / source |
|---------------|------------------|
| Firmware Version | `0x0002` (`DEVICE_SOFTWARE_VERSION`) |
| Laser Version | software high/low `0x0032` / `0x0033` (hex string concat as lws-ui) |
| Wire Feeder Version | `0x0035` |
| Gunhead SN | high/low `0x0038` / `0x0039` (hex string concat as lws-ui) |

Dart type and builder names SHALL use correct spelling (`Field`, not `Filed`). Wire encoding and addresses MUST NOT diverge from lws-ui.

#### Scenario: Successful device-info read populates fields

- **WHEN** a connected lower computer answers the device-info register reads
- **THEN** Gunhead SN, Firmware Version, Laser Version, and Wire Feeder Version are available to the UI as non-dash strings derived from those registers

#### Scenario: Partial or failed read shows dash

- **WHEN** a register read times out, CRC-fails, or returns no value for a field
- **THEN** that field’s display value is exactly `-`

### Requirement: Alarm Information temperature registers match lws-ui

The client SHALL read the four Monitor → Alarm Information welding-gun temperatures from consecutive input registers starting at `0x0061`:

| Display field | Address |
|---------------|---------|
| Motor Temperature | `0x0061` |
| Motor Driver Temperature | `0x0062` |
| Protective Mirror Temperature | `0x0063` |
| Collimator Temperature | `0x0064` |

Register words SHALL be interpreted as signed int16 and displayed as `value/10` °C with one decimal place. When `raw <= -999` or the read fails, the display value SHALL be `-`.

#### Scenario: Successful temperature block read

- **WHEN** input registers `0x0061`–`0x0064` return valid sensor data
- **THEN** the four temperature fields are available to the UI as formatted Celsius strings

### Requirement: Modbus work stays off the critical first-frame path

The app SHALL NOT block `runApp` / first frame on a successful Modbus transaction.

#### Scenario: Startup without slave

- **WHEN** the app starts with no Modbus slave attached
- **THEN** the first home frame still renders, and Modbus-backed fields may show `-` until a later successful poll
