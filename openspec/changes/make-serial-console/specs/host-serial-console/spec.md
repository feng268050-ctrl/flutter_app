## ADDED Requirements

### Requirement: Default TTL mode keeps existing miniterm backend

The repository SHALL provide `make serial-console` that accepts **`MODE=TTL|RS485|RS232`**, defaulting to **`TTL`** when unset. For **`MODE=TTL`**, the host script MUST use the existing pyserial **miniterm** path (project venv / `ensure-serial-venv.sh`, `-f direct`, default baud **1500000**, quit **`Ctrl+]`**). TTL MUST NOT require host `tio`. The operator MUST be able to override baud via **`SERIAL_BAUD`** in TTL mode. The script MUST print the resolved port, MODE, baud, and backend before connecting.

#### Scenario: Default session is TTL miniterm

- **WHEN** the operator runs `make serial-console` with a detectable USB-TTL port and no `MODE` override
- **THEN** the script launches pyserial miniterm at baud **1500000** and does not invoke `tio`

#### Scenario: Explicit TTL mode

- **WHEN** the operator runs `MODE=TTL make serial-console`
- **THEN** the script uses the miniterm backend with TTL defaults (unless `SERIAL_BAUD` overrides baud)

#### Scenario: TTL without tio installed

- **WHEN** `tio` is not on `PATH` and the operator runs default or `MODE=TTL` serial-console
- **THEN** the session still starts successfully via miniterm

### Requirement: RS485 and RS232 modes use tio

For **`MODE=RS485`** and **`MODE=RS232`**, the host script SHALL invoke **`tio`** for interactive continuous receive and keyboard transmit. Default baud SHALL be **115200** unless **`SERIAL_BAUD`** overrides it. When `tio` is not on `PATH`, the script MUST fail with a non-zero exit and an install hint. For `MODE=RS485`, the script SHALL pass `tio --rs-485` when the installed `tio` advertises that option and the host can use it; otherwise it MUST still open the port as a normal serial device and MUST NOT fail solely because RS-485 ioctl support is absent. Documentation SHALL state that electrical RS-485 vs RS-232 is determined by the adapter.

#### Scenario: RS485 preset uses tio

- **WHEN** the operator runs `MODE=RS485 make serial-console` without `SERIAL_BAUD`
- **THEN** the script launches `tio` at baud **115200**

#### Scenario: RS232 preset uses tio

- **WHEN** the operator runs `MODE=RS232 make serial-console` with a usable `SERIAL_PORT`
- **THEN** the script launches `tio` (without requiring `--rs-485`) at the resolved baud

#### Scenario: Baud override on tio modes

- **WHEN** the operator sets `MODE=RS485 SERIAL_BAUD=9600` (or RS232)
- **THEN** the script passes baud **9600** to `tio`

#### Scenario: Missing tio on RS485/RS232

- **WHEN** `tio` is not available on `PATH` and MODE is `RS485` or `RS232`
- **THEN** the script exits non-zero and prints how to install `tio` on the host

#### Scenario: RS485 without kernel RS-485 support

- **WHEN** `MODE=RS485` is selected on a host where `tio --rs-485` is unavailable or unsupported
- **THEN** the script still opens the serial device via `tio` for interactive RX/TX at the resolved baud

### Requirement: Optional log file for tio modes

When MODE is **`RS485`** or **`RS232`**, the host serial console SHALL allow redirecting session serial data to a host file by setting **`LOG`** or **`SERIAL_LOG`** to a filesystem path. When set, the script MUST enable `tio` logging to that path (e.g. `--log` and `--log-file`). The interactive terminal session MUST remain active. When **`SERIAL_LOG_APPEND=1`** is set with a log path, the script MUST request append mode if `tio` supports it. When MODE is **`TTL`** and a log path env is set, the script MUST fail clearly (TTL logging is out of scope) rather than silently ignoring the request.

#### Scenario: Log file on RS485/RS232

- **WHEN** the operator runs `MODE=RS485 LOG=/tmp/uart.log make serial-console` with a usable port
- **THEN** `tio` is started with logging enabled to `/tmp/uart.log` and the interactive session continues

#### Scenario: No log by default

- **WHEN** the operator runs `MODE=RS485 make serial-console` without `LOG` / `SERIAL_LOG`
- **THEN** the script MUST NOT require a log file and MUST still provide interactive RX/TX via `tio`

#### Scenario: Log env rejected in TTL mode

- **WHEN** the operator runs `MODE=TTL LOG=/tmp/uart.log make serial-console` (or default MODE with `LOG` set)
- **THEN** the script exits non-zero with a message that file logging requires `MODE=RS485` or `MODE=RS232`

### Requirement: Port discovery and documentation

The repository SHALL keep a way to list candidate host serial ports (`make serial-ports` or equivalent). Makefile `help` and README serial guidance MUST document `MODE=TTL|RS485|RS232`, backends (miniterm vs `tio`), `SERIAL_BAUD`, log env vars (tio modes), RS485/RS232 adapter use, and per-backend quit chords. AGENTS.md rebuild guidance SHALL mark this as host-only (no firmware rebuild).

#### Scenario: List ports

- **WHEN** the operator runs `make serial-ports`
- **THEN** the host lists available serial device paths without opening an interactive session

#### Scenario: Docs mention dual backend

- **WHEN** an operator reads Makefile help or the README serial section after this change
- **THEN** they can find that default TTL uses miniterm (`Ctrl+]`) and RS485/RS232 use `tio` (documented tio quit chord) plus MODE/baud/log usage
