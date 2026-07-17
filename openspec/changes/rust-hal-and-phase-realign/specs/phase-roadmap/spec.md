## ADDED Requirements

### Requirement: Authoritative phase list
Project planning documents SHALL use the following Linux stage list as authoritative for forward work:

- **P1** — Platform image + Hello World (completed)
- **P1.5** — Device debug + fast UI iteration (completed)
- **P2** — Hardware facility preparation: Modbus / RGB LED / speaker / ethernet / Wi‑Fi / BT / keyboard / mouse and related I/O validation (completed; includes former P2.1–P2.3 work)
- **P2.5** — A/B dual-partition flashing via Wi‑Fi/USB (`make upgrade`) (completed; former P2.4)
- **P3.0** — UI framework + IME submodules (**CyberUI** + CyberIME)
- **P3.1** — Rust HAL / Platform API
- **P3.2** — Linux emulator (UTM + Weston + flutter-embedded-linux + HAL; lower-unit comms)
- **P3.3** — AI library migration (`libai.so` + RKNN); target completion ~2026-07-22
- **P4** — Product UI and business migration (welder App pages and services)
- **P5.0** — Android compatibility (Modbus / GPIO LED / Wi‑Fi / BT; APK)
- **P5.1** — Upgrade Flutter Engine / SDK / flutter-pi (3.24 → 3.41 class)

#### Scenario: Plan header matches list
- **WHEN** a reader opens `docs/flutter-pi-hmi-plan.md` section 1
- **THEN** the stage table SHALL match the list above (names and completion marks)

### Requirement: Old phase mapping documented
The plan SHALL include a short old→new mapping so historical OpenSpec/change text that mentions P3/P4/P5/FrostUI remains interpretable.

#### Scenario: Mapping table present
- **WHEN** someone searches the plan for former stage ids (e.g. old P2.4, old P3.5, FrostUI)
- **THEN** they SHALL find an explicit mapping to P2.5, P5.1, and CyberUI respectively
