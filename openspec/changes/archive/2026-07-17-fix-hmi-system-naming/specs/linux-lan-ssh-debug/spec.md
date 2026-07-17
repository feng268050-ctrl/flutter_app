## MODIFIED Requirements

### Requirement: LAN SSH debug via on-demand unit

The image SHALL provide **`/usr/libexec/hmi/enable-ssh-debug.sh`** and **`disable-ssh-debug.sh`** controlling **`ssh-debug-lan.service`**.

#### Scenario: disable-ssh-debug stops lan unit

- **WHEN** operator runs `disable-ssh-debug` after enabling LAN SSH
- **THEN** `ssh-debug-lan.service` is stopped
