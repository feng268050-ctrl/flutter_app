## ADDED Requirements

### Requirement: Abstract LAN SSH debug controller with live state

The system SHALL provide a reusable Dart `SshDebugController` (or evolve the existing type) that can enable/disable on-demand LAN SSH (`lws-hmi-lan-ssh.service` / existing helpers) and expose **live enabled state** via a Stream (or equivalent change notifications). Callers MUST NOT need to poll `enable-ssh-debug.sh status` themselves for UI updates.

#### Scenario: Enable starts LAN SSH unit

- **WHEN** the controller is asked to enable LAN SSH debug
- **THEN** the LAN SSH helper/unit path runs successfully and the enabled Stream becomes true when the unit is active

#### Scenario: External stop updates Stream

- **WHEN** LAN SSH was enabled and an operator runs `systemctl stop lws-hmi-lan-ssh.service` outside the HMI
- **THEN** the enabled Stream becomes false without a Demo tap

### Requirement: Event-driven LAN SSH status via systemd

Linux SHALL observe `lws-hmi-lan-ssh.service` ActiveState primarily via **systemd D-Bus** (PropertiesChanged / Subscribe) or an equivalent long-lived subscription. Periodic Process invocation of status helpers on a fixed Timer MUST NOT be the primary status path. LAN SSH MUST remain non-restored across reboot per P2.3 policy (no boot auto-enable solely from prior session).

#### Scenario: No primary status Process poll

- **WHEN** the Demo SSH section remains open for more than ten seconds
- **THEN** the implementation does not rely on a repeating Timer that forks `enable-ssh-debug.sh status` each tick as the sole means of refreshing enabled state
