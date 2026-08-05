# host-serial-console Specification

## Purpose

Host Make/scripts for interactive serial I/O: default TTL via pyserial miniterm; RS485/RS232 via pyserial curses hex console (hex RX + fixed TX input bar), baud selection, and optional session log.

## Requirements

### Requirement: Default TTL mode keeps existing miniterm backend

The repository SHALL provide `make serial-console` that accepts **`MODE=TTL|RS485|RS232`**, defaulting to **`TTL`** when unset. For **`MODE=TTL`**, the host script MUST use the existing pyserial **miniterm** path (project venv / `ensure-serial-venv.sh`, `-f direct`, default baud **1500000**, quit **`Ctrl+]`**). TTL MUST NOT require host `tio` or the hex console. The operator MUST be able to override baud via **`BAUD`** in TTL mode. The script MUST print the resolved port, MODE, baud, and backend before connecting.

#### Scenario: Default session is TTL miniterm

- **WHEN** the operator runs `make serial-console` with a detectable USB-TTL port and no `MODE` override
- **THEN** the script launches pyserial miniterm at baud **1500000** and does not launch the hex console

#### Scenario: Explicit TTL mode

- **WHEN** the operator runs `MODE=TTL make serial-console`
- **THEN** the script uses the miniterm backend with TTL defaults (unless `BAUD` overrides baud)

#### Scenario: TTL without extra host serial tools

- **WHEN** host `tio` is absent and the operator runs default or `MODE=TTL` serial-console
- **THEN** the session still starts successfully via miniterm (project pyserial venv only)

### Requirement: RS485 and RS232 modes use pyserial hex console with TX bar

For **`MODE=RS485`** and **`MODE=RS232`**, the host script SHALL launch **`scripts/serial-hex-console.py`** via the project pyserial venv for interactive receive and transmit. Default baud SHALL be **115200** unless **`BAUD`** overrides it. The UI MUST provide scrolling **hex RX** and a fixed bottom **`TX>`** input bar where the operator types hex and presses Enter to send. RX MUST start a new line after an idle gap (default **5** ms, overridable via **`TIMESTAMP_TIMEOUT`**). The implementation MUST NOT require host `tio`. Documentation SHALL state that electrical RS-485 vs RS-232 is determined by the adapter and that the host opens plain serial.

#### Scenario: RS485 preset uses hex console

- **WHEN** the operator runs `MODE=RS485 make serial-console` without `BAUD`
- **THEN** the script launches the hex console at baud **115200** with a visible TX input bar

#### Scenario: RS232 preset uses hex console

- **WHEN** the operator runs `MODE=RS232 make serial-console` with a usable `PORT`
- **THEN** the script launches the hex console at the resolved baud with hex RX and TX bar

#### Scenario: Baud override on hex modes

- **WHEN** the operator sets `MODE=RS485 BAUD=9600` (or RS232)
- **THEN** the hex console opens the port at baud **9600**

#### Scenario: Hex TX from input bar

- **WHEN** the operator types hex (e.g. `01 03 00 00`) in the TX bar and presses Enter
- **THEN** those bytes are written to the serial port and a TX hex line appears in the RX pane / log stream

#### Scenario: Idle gap newline

- **WHEN** RX bytes arrive then go idle longer than the configured timestamp timeout
- **THEN** the console ends the current hex line so the next burst starts on a new line

#### Scenario: No tio dependency

- **WHEN** `tio` is not on `PATH` and MODE is `RS485` or `RS232`
- **THEN** the session still starts via the pyserial hex console (venv present)

### Requirement: Optional log file for hex-console modes

When MODE is **`RS485`** or **`RS232`**, the host serial console SHALL allow writing session lines to a host file by setting **`LOG_FILE`** to a filesystem path. When set, the hex console MUST append or overwrite that path according to **`LOG_APPEND`**. The interactive session MUST remain active. When MODE is **`TTL`** and a log path env is set, the script MUST fail clearly (TTL logging is out of scope) rather than silently ignoring the request.

#### Scenario: Log file on RS485/RS232

- **WHEN** the operator runs `MODE=RS485 LOG_FILE=/tmp/uart.log make serial-console` with a usable port
- **THEN** session lines are written to `/tmp/uart.log` and the interactive hex console continues

#### Scenario: No log by default

- **WHEN** the operator runs `MODE=RS485 make serial-console` without `LOG_FILE`
- **THEN** the script MUST NOT require a log file and MUST still provide interactive RX/TX via the hex console

#### Scenario: Log env rejected in TTL mode

- **WHEN** the operator runs `MODE=TTL LOG_FILE=/tmp/uart.log make serial-console` (or default MODE with `LOG_FILE` set)
- **THEN** the script exits non-zero with a message that file logging requires `MODE=RS485` or `MODE=RS232`

### Requirement: Port discovery and documentation

The repository SHALL keep a way to list candidate host serial ports (`make serial-ports` or equivalent). Makefile `help` and README serial guidance MUST document `MODE=TTL|RS485|RS232`, backends (miniterm vs hex console), `PORT` / `BAUD`, log env vars (hex modes), RS485/RS232 adapter use, TX bar usage, and per-backend quit chords. AGENTS.md rebuild guidance SHALL mark this as host-only (no firmware rebuild).

#### Scenario: List ports

- **WHEN** the operator runs `make serial-ports`
- **THEN** the host lists available serial device paths without opening an interactive session

#### Scenario: Docs mention dual backend

- **WHEN** an operator reads Makefile help or the README serial section after this change
- **THEN** they can find that default TTL uses miniterm (`Ctrl+]`) and RS485/RS232 use the hex console (Esc / `:q`, bottom TX bar) plus MODE/baud/log usage
