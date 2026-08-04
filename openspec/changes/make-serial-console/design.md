## Context

Host engineers use `make serial-console` → `scripts/serial-console.sh` with a project pyserial venv and `serial.tools.miniterm` against macOS `/dev/cu.usb*` (USB-TTL → ynh960 debug UART / `ttyFIQ0` @ **1500000** 8N1). That TTL path is trusted and must remain the default.

Operators also need the same Make entry for **USB-RS485 / USB-RS232** (baud selection, live RX, typed TX, optional log file). **`tio`** fits those modes; it does **not** replace TTL miniterm.

## Goals / Non-Goals

**Goals:**

- One Make entry with **`MODE=TTL|RS485|RS232`**; default **TTL** = today’s miniterm behavior.
- RS485/RS232 via `tio`: baud override, continuous RX, keyboard TX, optional host log file.
- Clear missing-`tio` errors only for RS485/RS232; keep `SERIAL_PORT=` / `serial-ports` discovery.

**Non-Goals:**

- Migrating TTL off miniterm / requiring `tio` for default console.
- Packaging `tio` into the appliance rootfs or SSH-wrapping on-board UARTs.
- Replacing App Modbus / `PosixSerialPort` / libserialport.
- Changing DTS UART mux, FIQ console baud, or `serial-sniff`.
- Full GUI analyzer or protocol decoding.

## Decisions

### D1 — Dual backend: TTL = miniterm, RS485/RS232 = tio

- **Choice:** Branch in `serial-console.sh` on `MODE`. TTL keeps pyserial miniterm (`-f direct`, quit `Ctrl+]`). RS485/RS232 `exec tio …`.
- **Why:** Preserves FIQ/ANSI debug UX; adds field-bus sessions with tio’s baud/log/RS-485 flags without a TTL regression.
- **Alternatives:** All-tio (rejected — breaks TTL default); separate Make targets (more help clutter).

### D2 — `MODE=` names and defaults

| MODE | Backend | Default use | Default baud |
|------|---------|-------------|--------------|
| `TTL` (default if unset) | pyserial miniterm | USB-TTL → board FIQ | `1500000` |
| `RS485` | `tio` | USB-RS485 dongle | `115200` |
| `RS232` | `tio` | USB-RS232 dongle | `115200` |

- Accept case-insensitive values; normalize to upper for banners (`ttl` → `TTL`).
- Overrides: `SERIAL_BAUD` for all modes; optional framing env mapped to `tio` only for RS485/RS232; `SERIAL_PORT` / auto-pick as today.
- **Why:** Explicit media names match operator language; FIQ stays hard to mis-baud by accident when MODE unset.

### D3 — Log file is tio-only (RS485/RS232)

- Env: `LOG=` or `SERIAL_LOG=` → `tio --log --log-file`; optional `SERIAL_LOG_APPEND=1` → `--log-append`.
- If `LOG` is set with `MODE=TTL`, either ignore with a warning or fail with “use MODE=RS485/RS232 for logging” — prefer **fail clearly** so operators do not think TTL is logging.
- **Why:** User ask maps to tio logging; miniterm+tee breaks raw TTY.

### D4 — RS-485 software flag is best-effort (`MODE=RS485` only)

- Pass `tio --rs-485` when `tio --help` advertises it and the host can use it; on macOS / missing support, omit flag and still open as plain serial.
- Electrical RS-485 vs RS-232 is the dongle; software does not convert levels.

### D5 — Quit chords documented per backend (TTL not breaking)

- TTL: keep **`Ctrl+]`**.
- RS485/RS232: document tio **`Ctrl+t` then `q`**.
- Port busy check (`lsof`) retained before either backend.

### D6 — `tio` required only for RS485/RS232

- Missing `tio` → non-zero + install hint when MODE is RS485 or RS232.
- TTL must succeed without `tio` installed.

## Risks / Trade-offs

- [Operator sets LOG with TTL] → Mitigation: clear error directing to RS485/RS232.
- [Wrong MODE baud / garbled FIQ] → Mitigation: default MODE=TTL @ 1500000; print resolved port/MODE/baud/backend before launch.
- [macOS no `--rs-485`] → Mitigation: best-effort; USB-RS485 still works as plain serial.
- [Log file grows unbounded] → Mitigation: operator-chosen path; session ends on quit.
- [Concurrent HMI Modbus vs host RS485 on same bus] → Mitigation: doc; tool does not touch board `ttyS5`.

## Migration Plan

1. Land MODE branch + docs; operators install `tio` only when using RS485/RS232.
2. Existing `make serial-console` / `SERIAL_PORT=…` with no MODE keeps TTL miniterm.
3. No firmware/OTA impact; rollback = remove RS485/RS232 branch.

## Open Questions

- None blocking.
