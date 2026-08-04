## Why

`make serial-console` today is the host TTL debug path (pyserial miniterm → USB-TTL → board `ttyFIQ0` @ 1500000). That path must stay the default. Field and lab work also need the **same Make entry** for **USB-RS485 / USB-RS232**: hex RX (one line per idle burst), a **fixed TX input bar**, baud selection, and optional session log. TTL does not switch backends.

## What Changes

- Extend `scripts/serial-console.sh` with **`MODE=TTL|RS485|RS232`** (default **`TTL`**).
- **`MODE=TTL`**: keep the **existing** pyserial miniterm flow (venv, `-f direct`, quit `Ctrl+]`, default baud **1500000**); `SERIAL_BAUD=` override still works as today.
- **`MODE=RS485` / `MODE=RS232`**: launch **`scripts/serial-hex-console.py`** (curses + project pyserial venv) — scrolling **hex RX** (idle-gap newline), bottom **`TX>`** bar (hex + Enter to send); default baud **115200**; honor **`SERIAL_BAUD=`** and optional framing env.
- For RS485/RS232 only: optional **`LOG=`** / **`SERIAL_LOG=`** (+ **`SERIAL_LOG_APPEND=1`**) → session log file; reject log env under TTL with a clear error.
- No host **`tio`** dependency (tio lacks a separate TX input bar; macOS also rejects `tio --rs-485`).
- Refresh Makefile help + README for MODE matrix, hex console UX, and per-backend quit chords (`Ctrl+]` vs Esc / `:q`).
- **Out of scope:** shipping a serial GUI in the appliance rootfs; on-board `/dev/ttyS5` over SSH; replacing TTL miniterm; Modbus/App serial stack; kernel UART mux; protocol decoding.

## Capabilities

### New Capabilities

- `host-serial-console`: Host Make/scripts for interactive serial I/O — default TTL via existing miniterm; RS485/RS232 via pyserial curses hex console (RX hex + TX input bar), baud selection, and optional log file.

### Modified Capabilities

- (none — no archived capability defines host serial-console behavior today)

## Impact

- **Scripts:** `scripts/serial-console.sh` (branch on MODE); TTL keeps `ensure-serial-venv.sh` / miniterm; RS485/RS232 use `scripts/serial-hex-console.py` via the same venv.
- **Makefile / docs:** `help`, README serial section, AGENTS.md rebuild table (host-only; no firmware rebuild).
- **Host deps:** pyserial project venv only (no `tio`).
- **Operator UX:** default `make serial-console` unchanged in backend and quit key; new MODE/baud/log + hex TX bar documented for RS485/RS232.
