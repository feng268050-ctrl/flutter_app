# SUPERSEDED

This change was **merged into** [`rust-hal-and-phase-realign`](../2026-07-18-rust-hal-and-phase-realign/), which itself is **superseded** by active [`dart-hal-package`](../../dart-hal-package/).

**Original reason:** Event-driven OS observation was planned for a Rust HAL (P3.1), not a second rewrite of Dart `Linux*Controller` backends.

**What was absorbed (historical):**

- The “no primary Timer + Process status poll” rule
- The Demo → event-source matrix (ethernet, Wi‑Fi, BT, SSH, keyboard, datetime, backlight, volume)
- Explicit non-goals (Modbus, LED modes, orientation mid-session, HTTP probe)

Current Platform API direction: [`dart-hal-package/design.md`](../../dart-hal-package/design.md). Historical Rust notes: [`../2026-07-18-rust-hal-and-phase-realign/design.md`](../2026-07-18-rust-hal-and-phase-realign/design.md).

**Archive note:** Moved to `openspec/changes/archive/2026-07-17-platform-event-driven-ui/` without syncing delta specs into `openspec/specs/`.
