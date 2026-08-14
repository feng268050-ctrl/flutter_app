## 1. Protocol lock (cross-repo)

- [ ] 1.1 Confirm `hal-bluetooth-companion-and-accessories` companion HAL APIs needed by this change are available or stubbed (document dependency gate in `notes.md`)
- [ ] 1.2 Author `notes/companion-ble-protocol.md` for `api_ver=1`: UUIDs, advertise fields, JSON frames, provision payload, status codes, error codes, `system.info` fields
- [ ] 1.3 Align HAL companion method allowlist / characteristic handlers to the protocol note method ids
- [ ] 1.4 Copy or link the same protocol revision into `lasercyber-mobile` change `ble-companion-device-link` (record git path + revision in both `notes.md`)

## 2. Appliance identity and provision conformance

- [ ] 2.1 Implement Device Info GATT reads (SN, model, `api_ver`) from existing identity/HAL sources
- [ ] 2.2 Implement `system.info` RPC response shape per protocol note
- [ ] 2.3 Implement provision write + status notify wired to `WifiController` + vault; verify no PSK info logs
- [ ] 2.4 Reject unsupported `api_ver` / unknown methods with structured errors; add unit tests

## 3. Pairing mode session

- [ ] 3.1 Implement timed pairing-mode start/stop on top of HAL companion session (timeout, cancel)
- [ ] 3.2 Generate/display pairing correlation (short code and/or QR with SN) consistent with Device Info SN
- [ ] 3.3 Enforce bonding / open-window policy for provision writes during and after the window
- [ ] 3.4 Ensure session policy restores accessory-host availability when pairing ends

## 4. HMI pairing UX

- [ ] 4.1 Add Phone pairing entry (Settings/Demo) gated on companion capability
- [ ] 4.2 UI: start/stop, countdown, code/QR, connection status, error copy
- [ ] 4.3 Hide or soft-fail entry when companion unsupported
- [ ] 4.4 Localization for new strings (`make l10n` if ARBs touched)

## 5. Joint accept and docs

- [ ] 5.1 On-device checklist with Mobile Central: scan → bond → info → provision → cloud bind
- [ ] 5.2 Update HAL/App docs pointers to protocol note and sibling Mobile change
- [ ] 5.3 Keep ynh960 companion OEM flag gated until checklist pass (coordinate with prior change)

## 6. Explicit non-goals

- [ ] 6.1 Confirm out of scope in notes: Mobile UI implementation, SoftAP, SPP, helmet, LAN/cloud default-off
