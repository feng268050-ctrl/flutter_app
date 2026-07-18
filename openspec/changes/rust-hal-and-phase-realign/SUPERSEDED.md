# SUPERSEDED (HAL architecture)

The **Rust `hald` / IPC Platform API** approach in this change is **superseded** by [`dart-hal-package`](../dart-hal-package/).

**Still valid from work already merged to docs (do not revert blindly):**

- CyberUI rename and Frosted Glass / Cyber* API direction
- P1–P5.1 phase table reshuffle in `docs/flutter-pi-hmi-plan.md`
- Optional capabilities, network roles, product LEDs out of portable HAL (carried into the Dart HAL design)

**Discard / do not implement from this change:**

- Rust workspace / `hald` / protobuf daemon as HAL truth
- Tasks that scaffold `hal/` Rust crates as the Platform API

See `../dart-hal-package/design.md`.
