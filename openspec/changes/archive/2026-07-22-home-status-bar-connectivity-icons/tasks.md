## 1. Status-bar strip abstraction

- [x] 1.1 Add `HomeStatusBar` (or equivalent) under `features/home/presentation/` as a right-aligned row with consistent icon spacing/size
- [x] 1.2 Refactor `HomePage` to host the strip in one top-right `Positioned` and move `HomeCameraStatusIcon` into the strip as the rightmost child
- [x] 1.3 Confirm camera-only layout remains visually equivalent (widget test or manual smoke)

## 2. Connectivity phase mapping

- [x] 2.1 Add App-local Wi‑Fi status-bar phase mapper from `WifiRadioState` + `WifiConnectionPhase` (`hidden` / `connecting` / `connected` / `onIdle`)
- [x] 2.2 Add App-local Bluetooth status-bar phase mapper from `BluetoothAdapterState` + remotes (+ optional pairing challenge) (`hidden` / `connecting` / `connected` / `onIdle`)
- [x] 2.3 Unit-test both mappers for off→hidden, starting/associating→connecting, connected, and on+disconnected→onIdle

## 3. Wi‑Fi / Bluetooth icons

- [x] 3.1 Implement `HomeWifiStatusIcon` with phone-like connecting / connected / idle visuals (icon-font; optional signal bars from `signalDbm`)
- [x] 3.2 Implement `HomeBluetoothStatusIcon` with connecting / connected / idle visuals
- [x] 3.3 Wire icons into `HomeStatusBar` in order Wi‑Fi · Bluetooth · Camera; omit Wi‑Fi/BT children when phase is hidden
- [x] 3.4 Subscribe to `AppServices.wifi` / `AppServices.bluetooth` streams without blocking Home first paint (seed from `current*` snapshots)

## 4. Verification

- [x] 4.1 Widget tests: Wi‑Fi/BT hidden when off; visible when on; connecting style when associating/adapter starting; camera remains rightmost when others visible
- [x] 4.2 Run `flutter analyze` / targeted tests under `app/hmi/` for touched files
- [x] 4.3 On-device smoke (optional): toggle Wi‑Fi/BT in Settings and confirm Home strip updates live
