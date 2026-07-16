## Why

The HMI currently exposes Bluetooth only as a discoverable local adapter for incoming phone/PC connections, so operators cannot pair and use Bluetooth keyboards or mice from the device. Adding central-role discovery and connection for HID peripherals closes that input-device gap while preserving the existing discoverable/pairable and opt-in A2DP Sink behavior.

## What Changes

- Extend the Linux Bluetooth capability with central-role scanning, pairing, trusting, connecting, disconnecting, and removing of nearby Bluetooth devices.
- Support Bluetooth HID keyboards and mice through the standard BlueZ-to-Linux-input path so their events reach flutter-pi/Flutter without a custom Dart HID decoder.
- Keep existing incoming-peer management, local discoverability/pairability, and opt-in A2DP Sink controls available on the same adapter.
- Extend the Demo page Bluetooth section to scan for nearby devices, show scan/connection state, and initiate connection or pairing, with non-fatal error handling and no first-frame blocking.
- Add verification coverage for Bluetooth keyboard typing, Bluetooth mouse pointer/click/scroll behavior, reconnection, and coexistence with current Bluetooth roles.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `linux-bluetooth`: Expand the current local-adapter-only contract to include central-role discovery and outbound connection management, including Bluetooth HID keyboard and mouse operation alongside existing Bluetooth roles.
- `p2-device-demo-ui`: Replace the Bluetooth section's prohibition on central scanning with operator controls for scanning and connecting to nearby Bluetooth devices while retaining current adapter and incoming-peer controls.

## Impact

- Flutter platform abstractions and Linux implementation under `app/hmi/`, including Bluetooth models, state handling, and the Demo Bluetooth UI.
- BlueZ D-Bus or command-line integration, agent/pairing behavior, service policy, and rootfs scripts/configuration under the Buildroot overlay.
- Buildroot/kernel/runtime configuration only where required to expose Bluetooth HID devices through the existing evdev/libinput input path.
- Existing Bluetooth adapter, A2DP Sink, incoming-peer management, USB HID, mouse settings, and flutter-pi input behavior must remain compatible.
