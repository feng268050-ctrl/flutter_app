## ADDED Requirements

### Requirement: Event-driven Wi-Fi status from wpa control interface

The Linux `WifiController` implementation SHALL observe radio and association state primarily via a **long-lived attachment** to the wpa_supplicant **control interface**. Unsolicited control-interface events (and a reconciliation snapshot when attaching) SHALL update in-memory state and emit on the existing `radio` / `connection` Streams. Periodic spawning of `wpa_cli` or `ip` via `Process` on a fixed timer MUST NOT be the primary status path.

#### Scenario: External disconnect updates Streams

- **WHEN** Wi-Fi radio is on, the controller monitor is attached, and an operator runs `wpa_cli -i wlan0 disconnect` outside the HMI
- **THEN** the `connection` Stream emits a non-connected phase without requiring any Demo tap or `syncFromSystem` re-entry

#### Scenario: External reconnect updates Streams

- **WHEN** after an external disconnect the interface reassociates while the monitor remains attached
- **THEN** the `connection` Stream progresses toward associated / connected phases consistent with wpa state, and IPv4 fields update when an address is known

#### Scenario: No primary Process status poll

- **WHEN** Wi-Fi radio remains on for more than ten seconds with a stable association
- **THEN** the implementation does not rely on a repeating Timer that forks `wpa_cli status` each tick as the sole means of refreshing connection state

### Requirement: Control attach respects on-demand stack and UI-first restore

The control-interface monitor SHALL attach when the ctrl socket for the WLAN iface becomes available. While `wifi-wanted` is present but the socket is not yet available, the controller MAY emit `starting` / associating and retry attach with backoff. Attach and event handling MUST NOT block first-frame paint and MUST NOT run synchronous control I/O on the Flutter UI isolate.

#### Scenario: Wanted before socket exists

- **WHEN** `/var/lib/lws-hmi/wifi-wanted` exists at Demo open and wpa ctrl socket is not yet present
- **THEN** radio Stream reflects starting (or equivalent non-off) and later transitions to on when the monitor attaches and wpa reports a live interface state

## MODIFIED Requirements

### Requirement: Abstract Wi-Fi controller API for Linux client

The system SHALL provide a reusable Dart `WifiController` abstraction that exposes radio enablement, scan of visible networks, connect/disconnect/forget (including hidden SSIDs), wlan0 IPv4 mode, and connection status streams. Linux SHALL implement the abstraction using on-demand wpa_supplicant **without NetworkManager**, and SHALL drive status streams from the wpa_supplicant control-interface event path. Callers MUST depend on the abstract type, not the Linux concrete class.

#### Scenario: Radio enable starts deferred stack

- **WHEN** the controller is asked to enable Wi-Fi while the radio is off
- **THEN** the Linux implementation brings up the deferred Wi-Fi stack without requiring those units to be in `multi-user.target.wants`

#### Scenario: Scan returns visible access points

- **WHEN** Wi-Fi radio is on and scan is requested
- **THEN** the controller returns access points including SSID when broadcast and a signal strength indicator when available

#### Scenario: Connect to visible WPA2-PSK network

- **WHEN** the user connects to a visible WPA2-PSK network with a correct passphrase
- **THEN** connection state reaches connected with a non-empty wlan0 IPv4 address when IPv4 mode is DHCP and DHCP succeeds

#### Scenario: Connect to hidden SSID

- **WHEN** the user connects with a manually entered SSID, passphrase, and hidden=true
- **THEN** the Linux implementation configures wpa with `scan_ssid=1` (or equivalent) and attempts association without requiring that SSID to appear in a prior scan result list

#### Scenario: Forget removes persisted network

- **WHEN** forget is called for a saved SSID
- **THEN** that network is removed from the persistent wpa configuration and is no longer listed as saved

#### Scenario: Failures do not crash the process

- **WHEN** association or IP configuration fails
- **THEN** the controller emits a failed/disconnected status and MUST NOT terminate the Flutter process

#### Scenario: Status available to any WifiController listener

- **WHEN** a caller other than the P2 Demo listens to `radio` and `connection` Streams
- **THEN** that caller observes the same event-driven transitions as the Demo without a separate poll loop
