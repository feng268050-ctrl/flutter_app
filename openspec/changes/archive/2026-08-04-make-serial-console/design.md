## Context

Host engineers use `make serial-console` → `scripts/serial-console.sh` with a project pyserial venv and `serial.tools.miniterm` against macOS `/dev/cu.usb*` (USB-TTL → ynh960 debug UART / `ttyFIQ0` @ **1500000** 8N1). That TTL path is trusted and must remain the default.

Operators also need the same Make entry for **USB-RS485 / USB-RS232**: live **hex** RX, a **separate TX input bar**, baud selection, and optional log file. An early design used host **`tio`**, but tio has no fixed TX bar and macOS rejects `tio --rs-485` at connect time — so RS485/RS232 use an in-repo **curses hex console** instead.

## Goals / Non-Goals

**Goals:**

- One Make entry with **`MODE=TTL|RS485|RS232`**; default **TTL** = today’s miniterm behavior.
- RS485/RS232 via pyserial curses hex console: hex RX with idle-gap newlines, fixed bottom TX bar, baud/framing override, optional host log file.
- Keep `SERIAL_PORT=` / `serial-ports` discovery; no host `tio` required.

**Non-Goals:**

- Migrating TTL off miniterm.
- Packaging a serial GUI into the appliance rootfs or SSH-wrapping on-board UARTs.
- Replacing App Modbus / `PosixSerialPort` / libserialport.
- Changing DTS UART mux, FIQ console baud, or `serial-sniff`.
- Full protocol analyzer / Modbus decode.

## Decisions

### D1 — Dual backend: TTL = miniterm, RS485/RS232 = curses hex console

- **Choice:** Branch in `serial-console.sh` on `MODE`. TTL keeps pyserial miniterm (`-f direct`, quit `Ctrl+]`). RS485/RS232 `exec` `scripts/serial-hex-console.py` via `ensure-serial-venv.sh`.
- **Why:** Preserves FIQ/ANSI debug UX; field-bus sessions need hex display + a real TX input bar (tio cannot provide the latter).
- **Alternatives:** All-tio (rejected — no TX bar; macOS `--rs-485` fails); separate Make targets (more help clutter); GUI apps (extra host deps).

### D2 — `MODE=` names and defaults

| MODE | Backend | Default use | Default baud |
|------|---------|-------------|--------------|
| `TTL` (default if unset) | pyserial miniterm | USB-TTL → board FIQ | `1500000` |
| `RS485` | `serial-hex-console.py` | USB-RS485 dongle | `115200` |
| `RS232` | `serial-hex-console.py` | USB-RS232 dongle | `115200` |

- Accept case-insensitive values; normalize to upper for banners (`ttl` → `TTL`).
- Overrides: `SERIAL_BAUD` for all modes; optional framing env (`SERIAL_DATABITS` / `SERIAL_PARITY` / `SERIAL_STOPBITS`) for RS485/RS232; `SERIAL_PORT` / auto-pick as today.
- **Why:** Explicit media names match operator language; FIQ stays hard to mis-baud by accident when MODE unset.

### D3 — Log file is hex-console-only (RS485/RS232)

- Env: `LOG=` or `SERIAL_LOG=` → session log written by the hex console; optional `SERIAL_LOG_APPEND=1`.
- If `LOG` is set with `MODE=TTL`, **fail clearly** (“use MODE=RS485/RS232 for logging”).
- **Why:** Operators must not think TTL is logging; miniterm+tee breaks raw TTY.

### D4 — Hex RX + idle-gap newlines; fixed TX bar

- RX displayed as hex; a new line after RX idle (`SERIAL_TIMESTAMP_TIMEOUT`, default **5** ms) ≈ one UART/Modbus burst per line.
- Bottom curses **`TX>`** bar: type hex (`01 03 …` / `0x01…`), Enter to send; quit via **Esc** or `:q` / `quit` / `exit`.
- Electrical RS-485 vs RS-232 is the dongle; software opens plain serial (no RS-485 ioctl).

### D5 — Quit chords documented per backend (TTL not breaking)

- TTL: keep **`Ctrl+]`**.
- RS485/RS232: **Esc** or **`:q`** in the TX bar.
- Port busy check (`lsof`) retained before either backend.

### D6 — No host `tio`

- RS485/RS232 use the project pyserial venv only (same as TTL tooling).
- TTL must succeed without any extra host serial GUI package.

## Risks / Trade-offs

- [Operator sets LOG with TTL] → Mitigation: clear error directing to RS485/RS232.
- [Wrong MODE baud / garbled FIQ] → Mitigation: default MODE=TTL @ 1500000; print resolved port/MODE/baud/backend before launch.
- [Idle timeout merges/splits frames] → Mitigation: tunable `SERIAL_TIMESTAMP_TIMEOUT`; default 5 ms.
- [Log file grows unbounded] → Mitigation: operator-chosen path; session ends on quit.
- [Concurrent HMI Modbus vs host RS485 on same bus] → Mitigation: doc; tool does not touch board `ttyS5`.
- [curses UX on tiny terminals] → Mitigation: minimum size check + status hint.

## Migration Plan

1. Land MODE branch + hex console + docs; no `tio` install step.
2. Existing `make serial-console` / `SERIAL_PORT=…` with no MODE keeps TTL miniterm.
3. No firmware/OTA impact; rollback = remove RS485/RS232 branch / hex console script.

## Open Questions

- None blocking.
