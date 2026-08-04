## 1. Host serial-console script (dual backend)

- [ ] 1.1 Extend `scripts/serial-console.sh` with `MODE=TTL|RS485|RS232` (default `TTL`, case-insensitive); keep shared `--list` / `--help`, `SERIAL_PORT` auto-pick, busy `lsof` check, and print resolved port/MODE/baud/backend before launch
- [ ] 1.2 Keep **TTL** on existing pyserial miniterm (`ensure-serial-venv.sh`, `-f direct`, default baud `1500000`, quit `Ctrl+]`); do not require `tio` for TTL
- [ ] 1.3 Implement **RS485/RS232** via `tio` (require `tio` on `PATH` with install hint); defaults baud `115200`; honor `SERIAL_BAUD` / optional framing env; for RS485 feature-detect `--rs-485` without failing when unsupported
- [ ] 1.4 Wire `LOG` / `SERIAL_LOG` (+ optional `SERIAL_LOG_APPEND=1`) only for RS485/RS232 → `tio --log --log-file`; reject log env under TTL with a clear error

## 2. Make targets and docs

- [ ] 2.1 Update Makefile `serial-console` / `serial-ports` `help` for MODE matrix, dual backend, baud, log (tio modes), and quit chords; pass through relevant env if needed
- [ ] 2.2 Document TTL (unchanged) vs RS485/RS232 (`tio`) in README serial section; add AGENTS.md rebuild table row (host-only: exercise `make serial-console` / `make serial-ports`; no firmware rebuild)

## 3. Verification

- [ ] 3.1 Smoke without hardware: default/`MODE=TTL` works without `tio`; `MODE=RS485` with missing `tio` fails clearly; `LOG=` under TTL fails clearly; `make serial-ports` / `--help` show MODE matrix
- [ ] 3.2 With USB adapter when available: TTL @ 1500000 miniterm; `MODE=RS485` / `RS232` @ 115200 via `tio`; `SERIAL_BAUD=` override; `LOG=` logs while interactive RX/TX works
