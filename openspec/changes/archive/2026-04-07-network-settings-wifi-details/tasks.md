## 1. Navigation and screen scaffolding

- [x] 1.1 Add a connected-network details entry point from the Wireless Network flow to open a dedicated WiFi details screen.
- [x] 1.2 Implement the WiFi details screen structure with a top back button and layout aligned to current app UI style.
- [x] 1.3 Add/adjust string and resource entries needed for details labels, placeholders, and action text.

## 2. WiFi details data presentation

- [x] 2.1 Implement data mapping for required fields: IP Address, Subnet Mask, and Router.
- [x] 2.2 Implement data mapping for additional simplified fields (DNS, signal strength, link speed, security type, frequency/band, MAC) with conditional visibility or fallback display.
- [x] 2.3 Add consistent placeholder behavior for unavailable values and ensure the page renders safely with partial data.

## 3. Forget network flow

- [x] 3.1 Add a `Forget This Network` action with confirmation UX in the WiFi details screen.
- [x] 3.2 Implement operation sequencing to disconnect the current WiFi connection and then remove the saved network configuration.
- [x] 3.3 Add explicit success/failure user feedback for partial or full failure cases without crashing or inconsistent state.

## 4. Validation and regression checks

- [x] 4.1 Verify navigation and back behavior across entry and return paths in Network Settings.
- [x] 4.2 Validate displayed fields across normal, missing-data, and different network/security conditions.
- [x] 4.3 Validate forget behavior end-to-end (disconnect + remove) and ensure no regressions in existing WiFi list/connection flows.
