## 1. Roadmap documentation

- [x] 1.1 Rewrite `docs/flutter-pi-hmi-plan.md` §1 stage table and intro to the new P1–P5.1 list (CyberUI, HAL, emulator, AI, business, Android, engine)
- [x] 1.2 Rewrite §1.1 task tree and dependency paragraph for new numbering; fold former P2.1–P2.3 under completed P2; map former P2.4 → P2.5
- [x] 1.3 Add old→new phase / FrostUI→CyberUI mapping subsection
- [x] 1.4 Retitle §6.3 FrostUI → CyberUI (keep Frosted Glass policy; Cyber* API naming note)
- [x] 1.5 Update AGENTS.md project overview blurb for multi-product OS + CyberUI + HAL submodule direction
- [x] 1.6 Add brief HAL architecture pointer in plan (link to this change’s `design.md`)

## 2. HAL scaffold (parallel-safe)

- [ ] 2.1 Create `hal/` Rust workspace skeleton (`lws-hal-api`, `lws-hal-core`, `lws-hal-linux`, `hald`)
- [ ] 2.2 Add `boards/ynh960` profile stub: capability set, network role→iface map (`ethernet.primary`/`wifi.station` → today’s names), Modbus tty if needed; **no** RGB LED map
- [ ] 2.3 Document IPC/FFI v0 + **D12 type catalog** in `hal/README.md` (version, optional capabilities, `NetworkDevice` / Managers)
- [x] 2.6 Record D12 industry-style naming in design + plan §1.4
- [ ] 2.4 Add host `cargo test` smoke for profile parse (no board required)
- [ ] 2.5 Decide submodule vs in-tree for first milestone; record in `hal/README.md` / design open questions

## 3. Dart client + first cutover

- [ ] 3.1 Add Dart HAL client stub with `HalClient` + `Capabilities` + `Brightness` (backlight) only
- [ ] 3.2 Implement backlight in Rust wrapping existing `change-backlight` / sysfs get
- [ ] 3.3 Wire Demo backlight behind HAL (`BacklightController` façade OK temporarily) with legacy fallback flag
- [ ] 3.4 Publish P2 capability migration matrix (`legacy-dart` / `hal-shim` / `hal-native` / `out-of-hal`); mark product RGB LEDs `out-of-hal`

## 4. CyberUI naming prep (P3.0 track)

- [ ] 4.1 Reserve `packages/cyber_ui` and `packages/cyber_ime` paths in docs/README (submodule placeholders OK)
- [x] 4.2 Ensure plan and pubspec examples no longer prescribe `frost_ui` as the public package name

## 5. Event-driven observation (merged from `platform-event-driven-ui`)

- [x] 5.1 Mark `platform-event-driven-ui` SUPERSEDED; fold event matrix into this design D8 + rust-hal spec
- [ ] 5.2 Per HAL-migrated capability: implement Rust event source from matrix (eth/wifi/bt/ssh/keyboard/backlight/volume/datetime) before declaring that capability `hal-native`
- [ ] 5.3 Demo/Settings: Stream-only wiring for migrated surfaces; no primary status Timers
- [ ] 5.4 Device smokes for external changes (`ip link`, wpa, BlueZ/phone, systemctl ssh-debug, HID plug) update UI via HAL
- [ ] 5.5 Sketch P3.2 emulator board pack `sim` + flutter-embedded-linux notes in plan § emulator

## 6. Follow-ons

- [ ] 6.1 Continue capability migration per design D4 after backlight pilot
- [x] 6.2 Archive superseded `platform-event-driven-ui` when convenient (keep design.md as historical matrix source)
