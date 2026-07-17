# SUPERSEDED

This change is **merged into** [`rust-hal-and-phase-realign`](../../rust-hal-and-phase-realign/).

**Reason:** Event-driven OS observation belongs in the **Rust HAL** (P3.1), not as a second rewrite of Dart `Linux*Controller` backends. Implementing netlink/wpa/D-Bus/udev here would be throwaway work once `hald` owns the Platform API.

**What was absorbed:**

- The “no primary Timer + Process status poll” rule
- The Demo → event-source matrix (ethernet, Wi‑Fi, BT, SSH, keyboard, datetime, backlight, volume)
- Explicit non-goals (Modbus, LED modes, orientation mid-session, HTTP probe)

See `../../rust-hal-and-phase-realign/design.md` **D8** and `../../rust-hal-and-phase-realign/specs/rust-hal/spec.md` (Event-oriented observation).

**Archive note:** Moved to `openspec/changes/archive/2026-07-17-platform-event-driven-ui/` without syncing delta specs into `openspec/specs/` (work was never applied; requirements live under the HAL change).

