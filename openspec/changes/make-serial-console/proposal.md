## Why

`make serial-console` today is the host TTL debug path (pyserial miniterm → USB-TTL → board `ttyFIQ0` @ 1500000). That path must stay the default. Field and lab work also need the **same Make entry** for **USB-RS485 / USB-RS232**: pick baud, continuous RX, keyboard TX, and optional RX log to a file. Those media use **`tio`**; TTL does not switch backends.

## What Changes

- Extend `scripts/serial-console.sh` with **`MODE=TTL|RS485|RS232`** (default **`TTL`**).
- **`MODE=TTL`**: keep the **existing** pyserial miniterm flow (venv, `-f direct`, quit `Ctrl+]`, default baud **1500000**); `SERIAL_BAUD=` override still works as today.
- **`MODE=RS485` / `MODE=RS232`**: invoke host **`tio`** for interactive continuous RX + keyboard TX; default baud **115200**; always allow **`SERIAL_BAUD=`** (and optional framing env) override.
- For RS485/RS232 only: optional **`LOG=`** / **`SERIAL_LOG=`** → `tio --log --log-file …` (append when requested); for `MODE=RS485`, best-effort **`tio --rs-485`** when the host/`tio` support it.
- Fail clearly if `tio` is missing **only when** MODE is RS485 or RS232 (TTL must not require `tio`).
- Refresh Makefile help + README for MODE matrix, RS485/RS232 wiring, and per-backend quit chords (`Ctrl+]` vs tio `Ctrl+t` then `q`).
- **Out of scope:** shipping `tio` in the appliance rootfs; on-board `/dev/ttyS5` over SSH; replacing TTL miniterm; Modbus/App serial stack; kernel UART mux.

## Capabilities

### New Capabilities

- `host-serial-console`: Host Make/scripts for interactive serial I/O — default TTL via existing miniterm; RS485/RS232 via `tio` with baud selection, continuous RX, keyboard TX, and optional log file.

### Modified Capabilities

- (none — no archived capability defines host serial-console behavior today)

## Impact

- **Scripts:** `scripts/serial-console.sh` (branch on MODE); TTL keeps `ensure-serial-venv.sh` / miniterm; RS485/RS232 need host `tio`.
- **Makefile / docs:** `help`, README serial section, AGENTS.md rebuild table (host-only; no firmware rebuild).
- **Host deps:** `tio` only for RS485/RS232 (`brew install tio` / distro package).
- **Operator UX:** default `make serial-console` unchanged in backend and quit key; new MODE/baud/log documented for RS485/RS232.
