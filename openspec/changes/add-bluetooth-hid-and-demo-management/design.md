## Context

The current ynh960 Bluetooth stack uses an AIC8800D80 controller, BlueZ, a persistent headless `bluetoothctl` pairing agent, and optional BlueZ-ALSA A2DP Sink. The Dart `BluetoothController` models the HMI only as a discoverable local adapter and polls `bluetoothctl` for adapter and peer state; the Demo consequently has no outbound discovery or connection flow.

Bluetooth HID needs more than a scan button. BlueZ must pair and connect the peripheral, the pairing agent must handle keyboard/passkey and mouse/JustWorks exchanges, and the resulting HID device must appear in Linux input so flutter-pi receives ordinary key and pointer events. Existing kernel configuration visibly enables generic/USB HID, but Bluetooth Classic HIDP and BLE HOG/UHID support must be audited against the final kernel and BlueZ build.

There is a known board-specific constraint: AIC8800D80 has returned `ENOSYS` during BlueZ BR/EDR initiator-side SDP browsing. The current phone/A2DP Sink path avoids that by disabling reverse service discovery and allowing the phone to initiate its media connection. Outbound Classic HID therefore requires an early hardware spike; BLE HOGP may use a different path but does not by itself satisfy compatibility with every Bluetooth keyboard or mouse.

The in-progress `platform-event-driven-ui` change also modifies `linux-bluetooth` to replace polling with BlueZ D-Bus observation. This change must be implemented against that D-Bus direction and its delta spec must be rebased if the other change is archived first, so neither change silently restores the old local-adapter-only contract.

## Goals / Non-Goals

**Goals:**

- Discover, pair, trust, connect, disconnect, and remove nearby Bluetooth peripherals from the existing Demo Bluetooth section.
- Make representative Bluetooth keyboards and mice usable through Linux input and the existing flutter-pi/Flutter input path.
- Preserve local discoverability/pairability, incoming peer management, and opt-in A2DP Sink on the same adapter.
- Expose scan, device, connection, and pairing-challenge state through the reusable abstract controller without blocking first paint.
- Use BlueZ D-Bus as the primary event and control plane, consistent with `platform-event-driven-ui`.

**Non-Goals:**

- A2DP Source, Bluetooth headset output, HFP, custom BLE GATT provisioning, or arbitrary application-level GATT browsing.
- A custom Dart decoder for HID reports.
- Persistently scanning in the background.
- Claiming support for a Bluetooth transport/profile that the AIC firmware and final kernel cannot pass on-device acceptance tests.
- Changing USB HID behavior or the existing mouse-settings API.

## Decisions

### D1 — Extend the controller around BlueZ objects, not “incoming” direction

`BluetoothController` will expose a unified device snapshot/stream plus scan state and operations such as `startScan`, `stopScan`, `pairAndConnect`, `disconnect`, and `remove`. Device models will include address, display name, paired/trusted/connected state, advertised UUIDs or best-effort type, RSSI when available, and whether the device is currently discovered.

BlueZ `Device1` objects do not reliably encode whether a peer was “incoming” or “outgoing”; retaining separate lists would duplicate and misclassify the same bonded object. The Demo can present bonded/connected devices and current scan results as separate views derived from one canonical map keyed by BlueZ object path/address. Existing disconnect/remove behavior remains available.

Alternative considered: add a second `scannedDevices` model while leaving `incomingDevices` unchanged. This avoids an API rename but creates two sources of truth and ambiguous duplicate rows after pairing.

### D2 — Use one long-lived BlueZ D-Bus client for observation and control

The Linux implementation will use `org.bluez.Adapter1.StartDiscovery/StopDiscovery`, `org.bluez.Device1.Pair/Connect/Disconnect`, `Adapter1.RemoveDevice`, ObjectManager, and PropertiesChanged. Discovery will be bounded (default 15 seconds), cancellable, deduplicated, and stopped before pairing when required by BlueZ/controller behavior.

This aligns with the event-driven migration and avoids parsing transient `bluetoothctl` output or running multiple interactive `bluetoothctl` sessions. Existing shell helpers remain appropriate for deferred stack start/stop and BlueZ-ALSA service control.

Alternative considered: script `bluetoothctl scan on`, parse output, then issue `pair/connect`. It is easy to prototype but races with the persistent pairing agent, loses structured pairing events, and conflicts with the required D-Bus observation architecture.

### D3 — Replace competing default-agent behavior with an HMI-aware Agent1

A single BlueZ `Agent1` owner will serve both existing incoming phone/PC pairing and outbound peripherals while the HMI is running. The controller will expose structured pairing requests (confirmation, displayed passkey, requested PIN/passkey, authorization, cancellation) and responses needed by the Demo. Keyboard workflows that require typing a displayed code on the keyboard must show that code and instructions; JustWorks mouse flows may use the existing approved auto-confirm policy.

The existing `bt-pair-agent.sh` must be adjusted so it does not compete for the default agent. It may remain as a stack-level fallback only if ownership and failover are deterministic and existing incoming pairing still works after an HMI restart.

Alternative considered: retain the auto-yes log-scraping agent. It cannot reliably surface passkeys to the UI or correlate prompts to the selected device.

### D4 — Let BlueZ create standard Linux input devices

No Dart HID report protocol will be introduced. Classic HID shall use BlueZ’s input profile and kernel HIDP support; BLE keyboards/mice shall use BlueZ HOG with UHID as required by the final stack. The kernel/Buildroot audit will verify at least `CONFIG_BT_HIDP`, `CONFIG_UHID`, generic HID/input/evdev support, and that the BlueZ input/HOG plugins are present and not disabled.

Acceptance is based on `/dev/input/event*` appearance and end-to-end behavior in the existing Demo text field and pointer-enabled UI. The same mouse settings continue to apply at the common libinput/flutter-pi layer.

Alternative considered: consume HID GATT reports directly in Flutter. That would duplicate BlueZ/kernel input handling and would not integrate cleanly with system-wide focus, cursor, or future Settings surfaces.

### D5 — Treat Classic HID feasibility as a gated board spike

Before broad implementation, test one known Classic HID peripheral and one BLE HOGP peripheral (where available) directly with BlueZ on ynh960 and capture `bluetoothd`/kernel logs. If AIC initiator SDP prevents Classic HID, investigate a narrowly scoped BlueZ/controller workaround without re-enabling reverse discovery for phones.

The UI and API remain transport-neutral. Any unavoidable transport limitation must be documented with evidence and reflected in the final acceptance matrix; it must not be hidden behind a generic “connected” state.

### D6 — Preserve profile coexistence and serialize adapter mutations

Scanning and outbound pairing must not turn off discoverable, pairable, or A2DP Sink preferences. The controller will serialize scan/pair/remove operations, reconcile state after BlueZ restarts, and tolerate a phone plus HID peripherals being bonded concurrently. A bounded scan may temporarily increase radio contention, especially with Wi-Fi on the combo chip, but it will not run continuously.

Stopping Bluetooth retains current semantics: active links end while bonds and role preferences remain available for later restore.

### D7 — Keep the Demo asynchronous and explicit

The existing Bluetooth section will retain adapter, discoverable, pairable, A2DP, and bonded-peer controls, then add:

- a Scan/Stop action with progress and bounded timeout;
- deduplicated nearby-device rows with type/state/RSSI when known;
- Pair/Connect, Disconnect, and Remove actions appropriate to current state;
- pairing instructions or challenge response controls;
- non-fatal, device-specific error text and refresh from controller streams.

Initialization and discovery never gate first paint. Actions are disabled only when they conflict with the current adapter operation, not globally for unrelated existing controls.

## Risks / Trade-offs

- **[Risk] AIC8800D80 initiator SDP returns `ENOSYS` for Classic HID** → Gate implementation with on-device Classic/LE spikes; preserve `ReverseServiceDiscovery=false`; document or escalate a proven firmware/BlueZ limitation rather than weakening incoming A2DP.
- **[Risk] Pairing-agent replacement regresses phone pairing or A2DP Sink** → Use one Agent1 state machine, add incoming phone regression tests, and define deterministic fallback/re-registration after HMI or bluetoothd restart.
- **[Risk] Missing HIDP/UHID or BlueZ plugins in the image** → Audit final kernel config and target binaries/plugins, add only the required Buildroot/kernel options, and verify `/dev/input` creation on hardware.
- **[Risk] Parallel OpenSpec changes overwrite each other’s full `linux-bluetooth` requirement** → Rebase this delta against `platform-event-driven-ui` before implementation/archive and preserve its D-Bus event requirement.
- **[Risk] Scan and Wi-Fi contend on the combo radio** → Use bounded user-initiated scans, stop discovery before pairing when needed, and test with Wi-Fi connected.
- **[Trade-off] Unified device list changes an internal abstract API** → Update mocks/tests and all callers together; the cleaner BlueZ-aligned model avoids lasting direction ambiguity.
- **[Risk] Auto-accept pairing weakens security** → Limit automatic confirmation to the existing product policy while Pairable is enabled or an explicit outbound operation is active; surface other challenges and reject stale/unmatched requests.

## Migration Plan

1. Reconcile with the active event-driven Bluetooth change and complete the ynh960 Classic HID/BLE HOGP feasibility spike.
2. Add required kernel/Buildroot support and verify BlueZ profile availability without changing existing A2DP defaults.
3. Introduce the D-Bus device/discovery/pairing model and adapt the existing incoming-peer/A2DP behavior.
4. Replace or coordinate the default pairing agent, then add Demo scan/connect/challenge UI.
5. Run unit/widget tests and the hardware coexistence matrix: phone incoming pairing/A2DP, keyboard typing, mouse pointer/click/scroll, reconnect after Bluetooth toggle/reboot, and Wi-Fi-connected scanning.
6. Roll back by reverting the controller/UI/profile additions; preserve existing bonds/preferences and restore the current headless agent if the new Agent1 path cannot be made reliable.

## Open Questions

1. Which exact keyboard and mouse models/transports are the acceptance references? Default: test at least one Classic HID and one BLE HOGP device across keyboard/mouse coverage.
2. Does the pinned BlueZ/Dart D-Bus implementation support exporting `Agent1` cleanly under flutter-pi? Default: use the same D-Bus approach selected by `platform-event-driven-ui`; a small long-lived broker helper is acceptable only if exporting Agent1 in-process is blocked.
3. Can AIC8800D80 complete initiator-side Classic HID SDP with the current firmware after device-class filtering, or is a vendor/BlueZ fix required? This is a mandatory spike result, not an assumption.
