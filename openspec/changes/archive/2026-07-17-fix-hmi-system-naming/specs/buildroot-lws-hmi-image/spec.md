## MODIFIED Requirements

### Requirement: P2 network stack units and split state dirs in overlay

The rootfs overlay SHALL include functional units (`wlan-wpa.service`, `wlan-dhcp.service`, `eth0-network.service`, `settings-restore.service`) and seed/state stubs under **`var/lib/wpa_supplicant/`**, **`var/lib/network/`**, **`var/lib/bluetooth/`**, **`var/lib/hmi/`** — not a monolithic `var/lib/lws-hmi/`. Helpers MUST live under matching **`usr/libexec/{wpa,network,bluetooth,hmi}/`**.

#### Scenario: Overlay has wpa_supplicant state dir

- **WHEN** rootfs overlay is verified
- **THEN** `var/lib/wpa_supplicant/wpa_supplicant.conf` exists and `var/lib/lws-hmi/` does not

#### Scenario: eth0 helpers in network libexec

- **WHEN** rootfs overlay is verified
- **THEN** `apply-eth0.sh` is under `usr/libexec/network/`

#### Scenario: flutter-pi mouse prefs path

- **WHEN** operator inspects running image
- **THEN** flutter-pi reads mouse settings from `/var/lib/hmi/mouse.conf`
