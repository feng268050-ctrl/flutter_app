## MODIFIED Requirements

### Requirement: A2DP Sink opt-in gated by preference file

`bt-stack-up.sh` under **`/usr/libexec/bluetooth/`** MUST NOT start A2DP Sink unless **`/var/lib/bluetooth/bt-a2dp-sink`** is `1`. Volume pref **`/var/lib/bluetooth/bt-a2dp-volume`** SHALL be used by bluetooth libexec helpers.

#### Scenario: A2DP off when pref absent

- **WHEN** BT stack starts and `/var/lib/bluetooth/bt-a2dp-sink` is not `1`
- **THEN** A2DP Sink services are not started from `bt-stack-up.sh`

#### Scenario: BT wanted marker location

- **WHEN** Bluetooth radio is enabled from Demo
- **THEN** `/var/lib/bluetooth/bt-wanted` exists (not under `/var/lib/hmi/`)
